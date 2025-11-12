#!/bin/bash
set -euo pipefail

# Usage:
#   ./associate-policy-to-permission.sh <REALM> <ADMIN_USER> <ADMIN_PASS> <CLIENT_NAME> <PERMISSION_NAME> <POLICY_NAME>
#
# Example:
#   ./associate-policy-to-permission.sh myrealm admin adminpass kafka-broker cluster-admin-permission dev-cluster-admin

if [ $# -ne 6 ]; then
  echo "Usage: $0 <REALM> <ADMIN_USER> <ADMIN_PASS> <CLIENT_NAME> <PERMISSION_NAME> <POLICY_NAME>"
  exit 1
fi

REALM="$1"
ADMIN_USER="$2"
ADMIN_PASS="$3"
CLIENT_NAME="$4"
PERMISSION_NAME="$5"
POLICY_NAME="$6"

KCADM="/opt/keycloak/bin/kcadm.sh"
CONFIG_FILE="/tmp/kcadm.config"
KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8080}"

# Login (stores token in config file)
"$KCADM" config credentials --server "$KEYCLOAK_URL" --realm master --user "$ADMIN_USER" --password "$ADMIN_PASS" --config "$CONFIG_FILE"

# Helper: extract value by name from JSON returned by kcadm (no jq/awk)
# Finds first occurrence of "name" : "<NAME>" and the nearest "id" near it.
extract_id_by_name() {
  # $1 = JSON input, $2 = target name
  local json="$1"
  local name="$2"
  # normalize to single line to simplify sed
  local oneline
  oneline=$(echo "$json" | tr -d '\n\r\t')
  # find pattern where "name":"<name>" appears, then find an "id":"<id>" in that object
  # try both orders (id before name or name before id) by scanning the block around name
  # first try name then id
  local id
  id=$(echo "$oneline" | sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"'${name//\"/\\\"}'"[^}]*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' || true)
  if [ -n "$id" ]; then
    echo "$id"
    return 0
  fi
  # try id before name within same object
  id=$(echo "$oneline" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)"[^}]*"name"[[:space:]]*:[[:space:]]*"'${name//\"/\\\"}'".*/\1/p' || true)
  if [ -n "$id" ]; then
    echo "$id"
    return 0
  fi
  # not found
  return 1
}

# 1) get client UUID
clients_json=$("$KCADM" get clients -r "$REALM" --config "$CONFIG_FILE" 2>/dev/null)
CLIENT_UUID=$(echo "$clients_json" | grep -A1 "\"clientId\" *: *\"$CLIENT_NAME\"" | grep '"id"' | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1 || true)
# fallback robust search if above fails
if [ -z "$CLIENT_UUID" ]; then
  CLIENT_UUID=$(extract_id_by_name "$clients_json" "$CLIENT_NAME" || true)
fi

if [ -z "$CLIENT_UUID" ]; then
  echo "ERROR: Could not find client '$CLIENT_NAME' in realm '$REALM'."
  exit 2
fi
echo "Client UUID: $CLIENT_UUID"

# 2) get permission id
perms_json=$("$KCADM" get clients/"$CLIENT_UUID"/authz/resource-server/permission/resource -r "$REALM" --config "$CONFIG_FILE" 2>/dev/null)
PERMISSION_ID=$(echo "$perms_json" | grep -B1 "\"name\" *: *\"$PERMISSION_NAME\"" | grep '"id"' | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1 || true)
if [ -z "$PERMISSION_ID" ]; then
  # try robust extractor
  PERMISSION_ID=$(extract_id_by_name "$perms_json" "$PERMISSION_NAME" || true)
fi

if [ -z "$PERMISSION_ID" ]; then
  echo "INFO: Permission '$PERMISSION_NAME' not found. Creating it with empty resources/scopes..."
  # create a fallback permission (no resources/scopes) so we have an ID to update
  "$KCADM" create clients/"$CLIENT_UUID"/authz/resource-server/permission/resource -r "$REALM" --config "$CONFIG_FILE" -s name="$PERMISSION_NAME" >/dev/null
  # re-fetch
  perms_json=$("$KCADM" get clients/"$CLIENT_UUID"/authz/resource-server/permission/resource -r "$REALM" --config "$CONFIG_FILE" 2>/dev/null)
  PERMISSION_ID=$(extract_id_by_name "$perms_json" "$PERMISSION_NAME" || true)
fi

if [ -z "$PERMISSION_ID" ]; then
  echo "ERROR: Could not create or find permission '$PERMISSION_NAME'."
  exit 3
fi
echo "Permission ID: $PERMISSION_ID"

# 3) get policy id
policies_json=$("$KCADM" get clients/"$CLIENT_UUID"/authz/resource-server/policy -r "$REALM" --config "$CONFIG_FILE" 2>/dev/null)
POLICY_ID=$(extract_id_by_name "$policies_json" "$POLICY_NAME" || true)

if [ -z "$POLICY_ID" ]; then
  echo "ERROR: Policy '$POLICY_NAME' not found for client '$CLIENT_NAME'."
  exit 4
fi
echo "Policy ID: $POLICY_ID"

# 4) fetch current permission JSON
TMP_DIR=$(mktemp -d)
PERM_FILE="$TMP_DIR/perm.json"
"$KCADM" get clients/"$CLIENT_UUID"/authz/resource-server/permission/resource/"$PERMISSION_ID" -r "$REALM" --config "$CONFIG_FILE" > "$PERM_FILE"

if [ ! -s "$PERM_FILE" ]; then
  echo "ERROR: Failed to fetch permission JSON for id $PERMISSION_ID"
  rm -rf "$TMP_DIR"
  exit 5
fi

# 5) remove existing "policies" field if present (handles several formats)
#    Convert file to single-line, remove "policies":[...], then restore pretty-ish formatting.
ONE_LINE=$(tr -d '\n\r\t' < "$PERM_FILE")
# remove any existing "policies": [...] (non-greedy until closing bracket)
ONE_LINE_NO_POL=$(echo "$ONE_LINE" | sed -E 's/"policies"[[:space:]]*:[[:space:]]*\[[^]]*\],?//g')

# 6) append policies with the desired policy id
# Build JSON array with quoted id
POLICIES_JSON='["'"$POLICY_ID"'"]'

# If object ends with } add , "policies": [...] before last }
# Ensure there's no trailing comma issues
UPDATED_ONE_LINE=$(echo "$ONE_LINE_NO_POL" | sed -E 's/}[[:space:]]*$/,"policies":'"$POLICIES_JSON"'}'/)

# If sed didn't add (safeguard), fallback to simple append
if [ -z "$UPDATED_ONE_LINE" ]; then
  UPDATED_ONE_LINE=$(echo "$ONE_LINE_NO_POL" | sed -E 's/}$/,"policies":'"$POLICIES_JSON"'}/')
fi

# Write back to temp file with newlines for readability
# Insert newlines between object members for kcadm to accept (not required but helpful)
echo "$UPDATED_ONE_LINE" | sed 's/","/\", \"/g; s/},{/},\n{/g' > "$PERM_FILE.updated"

# 7) Update permission by sending the updated JSON file
"$KCADM" update clients/"$CLIENT_UUID"/authz/resource-server/permission/resource/"$PERMISSION_ID" -r "$REALM" --config "$CONFIG_FILE" -f "$PERM_FILE.updated"

if [ $? -eq 0 ]; then
  echo "✅ Associated policy '$POLICY_NAME' (id $POLICY_ID) with permission '$PERMISSION_NAME'."
else
  echo "❌ Failed to update permission."
  cat "$PERM_FILE.updated"
  rm -rf "$TMP_DIR"
  exit 6
fi

# cleanup
rm -rf "$TMP_DIR"
exit 0
