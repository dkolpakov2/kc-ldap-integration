#!/usr/bin/env bash
set -e

# -------------------------------------------------------------------
# Params:
#   1 = REALM
#   2 = CLIENT_ID (clientId, not UUID)
#   3 = RESOURCE_NAME (e.g. "cluster:*")
#   4 = SCOPE_NAME (e.g. "ClusterAction")
# -------------------------------------------------------------------

REALM="$1"
CLIENT_CLIENTID="$2"
RESOURCE_NAME="$3"
SCOPE_NAME="$4"

KCADM="/opt/keycloak/bin/kcadm.sh --config /tmp/kcadm.config"

# -------------------------------------------------------------------
echo "[INFO] Getting client UUID"
CLIENT_UUID=$($KCADM get clients -r "$REALM" --fields id,clientId --format csv \
    | grep "^.*,${CLIENT_CLIENTID}$" | cut -d, -f1)

if [[ -z "$CLIENT_UUID" ]]; then
  echo "[ERROR] Client not found: $CLIENT_CLIENTID"
  exit 1
fi

# -------------------------------------------------------------------
echo "[INFO] Getting resource ID for $RESOURCE_NAME"
RESOURCE_LIST=$($KCADM get clients/$CLIENT_UUID/authz/resource-server/resource -r "$REALM")

# Remove spaces for reliable grep
RESOURCE_CLEAN=$(printf '%s' "$RESOURCE_LIST" | tr -d ' ')

RESOURCE_ID=$(printf '%s' "$RESOURCE_CLEAN" \
    | grep -o "{[^}]*}" \
    | grep "\"name\":\"$RESOURCE_NAME\"" \
    | sed -n 's/.*"_id":"\([^"]*\)".*/\1/p')

if [[ -z "$RESOURCE_ID" ]]; then
  echo "[ERROR] Resource not found: $RESOURCE_NAME"
  exit 1
fi

# -------------------------------------------------------------------
echo "[INFO] Getting scope ID for $SCOPE_NAME"
SCOPE_LIST=$($KCADM get clients/$CLIENT_UUID/authz/resource-server/scope -r "$REALM")

SCOPE_CLEAN=$(printf '%s' "$SCOPE_LIST" | tr -d ' ')

SCOPE_ID=$(printf '%s' "$SCOPE_CLEAN" \
    | grep -o "{[^}]*}" \
    | grep "\"name\":\"$SCOPE_NAME\"" \
    | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')

if [[ -z "$SCOPE_ID" ]]; then
  echo "[ERROR] Scope not found: $SCOPE_NAME"
  exit 1
fi

# -------------------------------------------------------------------
echo "[INFO] Fetching current resource JSON"
RESOURCE_JSON=$($KCADM get clients/$CLIENT_UUID/authz/resource-server/resource/$RESOURCE_ID -r "$REALM")

# Remove spaces
RESOURCE_JSON=$(printf '%s' "$RESOURCE_JSON" | tr -d ' ')

# Extract current scopes array
CURRENT_SCOPES=$(printf '%s' "$RESOURCE_JSON" | sed -n 's/.*"scopes":\[\([^]]*\)\].*/\1/p')

# Build new scopes array
# Convert CSV style to array
NEW_SCOPES="$CURRENT_SCOPES,\"$SCOPE_ID\""
NEW_SCOPES=$(echo "$NEW_SCOPES" | sed 's/^,//')  # remove leading comma

SCOPES_JSON="[$NEW_SCOPES]"

# Escape quotes for kcadm
SCOPES_ESCAPED=$(printf '%s' "$SCOPES_JSON" | sed 's/"/\\"/g')

# -------------------------------------------------------------------
echo "[INFO] Updating resource with new scopes"

$KCADM update clients/$CLIENT_UUID/authz/resource-server/resource/$RESOURCE_ID \
  -r "$REALM" \
  "-s scopes=$SCOPES_ESCAPED"

echo "[SUCCESS] Updated resource '$RESOURCE_NAME' with scope '$SCOPE_NAME'"
