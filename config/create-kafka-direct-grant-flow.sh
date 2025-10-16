#!/bin/bash
# ============================================================
# Script: create-kafka-direct-grant-flow.sh
# Purpose: Create custom Authentication Flow "kafka-direct-grant"
#          with execution "X509/Validate Username"
# Compatible: Keycloak 21+, no jq/awk dependencies
# ============================================================
#PUT /admin/realms/{realm}/authentication/executions/{executionId}
#{  "flowId": "{subFlowId}" }
#PUT /admin/realms/{realm}/authentication/executions/{executionId}
#-s flowId={subFlowId}



set -e

KEYCLOAK_BIN="/opt/keycloak/bin/kcadm.sh"
KC_URL="http://localhost:8080"         # update KC URL
REALM="kafka-realm"
ADMIN_USER="admin"
ADMIN_PASS="admin"

FLOW_ALIAS="kafka-direct-grant"
EXECUTION_PROVIDER="x509-username"     # Keycloak provider ID for X509 username validation

# -----------------------------
# 1️ Login to Keycloak
# -----------------------------
echo " Logging in to Keycloak..."
$KEYCLOAK_BIN config credentials --server "$KC_URL" --realm master --user "$ADMIN_USER" --password "$ADMIN_PASS"

# -----------------------------
# 2️ Create Realm if Missing
# -----------------------------
echo " Checking if realm '$REALM' exists..."
REALM_EXISTS=$($KEYCLOAK_BIN get realms --fields realm | grep "\"realm\":\"$REALM\"" || true)
if [ -z "$REALM_EXISTS" ]; then
  echo " Creating realm '$REALM'..."
  $KEYCLOAK_BIN create realms -s realm="$REALM" -s enabled=true
else
  echo " Realm '$REALM' already exists."
fi

# -----------------------------
# 3️ Create Authentication Flow
# -----------------------------
echo " Creating authentication flow '$FLOW_ALIAS'..."
$KEYCLOAK_BIN create authentication/flows -r "$REALM" \
  -s alias="$FLOW_ALIAS" \
  -s description="Kafka direct grant flow using X509 certificate validation" \
  -s providerId="basic-flow" \
  -s topLevel=true \
  -s builtIn=false \
  || echo " Flow '$FLOW_ALIAS' may already exist, continuing..."
sleep 5
# -----------------------------
# 4️ Retrieve Flow ID
# -----------------------------
echo " Getting flow ID for '$FLOW_ALIAS'..."
FLOW_LIST=$($KEYCLOAK_BIN get authentication/flows -r "$REALM")

FLOW_ID=$(echo "$FLOW_LIT" | sed -n "/\"alias\":\"$FLOW_ALIAS\"/s/.*\"id\":\"\([^\"]*\)\".*/\1/p" | head -n1)
# output:
# FLOW_LIST=[{"id":""12345","alias":"kafak-direct-grant","description":"something","providerId":"basic-flow", "topLevel":true, "builtIn":false, "authenticationExecutions":[]}]

# Debug output
echo "[DEBUG] Looking for flow alias: $FLOW_ALIAS"
FLOW_FILE="flow-list.json"

# Extract the ID by matching alias ignoring accidental typos/spaces
FLOW_ID=$(sed -n "s/.*\"id\":\"\([^\"]*\)\".*\"alias\":\"[[:space:]]*$FLOW_ALIAS[[:space:]]*\".*/\1/p" "$FLOW_FILE")
# Normalize JSON: remove spaces and newlines
CLEANED=$(tr -d '\n\r' < "$FLOW_FILE" | sed 's/[[:space:]]//g')

# last try to clean
# Combine multiline JSON into a single line (sed and tr safe)
CLEANED=$(tr -d '\n\r' < "$FLOW_FILE" | tr -d ' ')

# Optional: show available aliases
echo "[DEBUG] Available aliases:"
echo "$CLEANED" | sed 's/.*"alias":"\([^"]*\)".*/\1\n/g'

# Escape alias for regex
ESCAPED_ALIAS=$(printf '%s\n' "$FLOW_ALIAS" | sed 's/[]\/$*.^[]/\\&/g')

# Match id value preceding the alias
FLOW_ID=$(echo "$CLEANED" | sed -n "s/.*{\"id\":\"\([^\"]*\)\",\"alias\":\"$ESCAPED_ALIAS\".*/\1/p")

# Debug: check alias presence
if ! echo "$CLEANED" | grep -q "\"alias\":\"$FLOW_ALIAS\""; then
  echo "[ERROR] Alias '$FLOW_ALIAS' not found. Available aliases:"
  echo "$CLEANED" | sed 's/.*"alias":"\([^"]*\)".*/\1\n/g'
  exit 1
fi

# Extract ID before alias
FLOW_ID=$(echo "$CLEANED" | sed -n "s/.*\"id\":\"\([^\"]*\)\"[^}]*\"alias\":\"$FLOW_ALIAS\".*/\1/p")



# Fallback if not found (show what's actually in the file)
if [ -z "$FLOW_ID" ]; then
  echo "[ERROR] Could not find flow ID for '$FLOW_ALIAS' in $FLOW_FILE"
  echo "[DEBUG] Available aliases:"
  grep -o '"alias":"[^"]*"' "$FLOW_FILE"
  exit 1
fi

# Try both forms for realm flag
echo "[INFO] Fetching flows for realm: $REALM"
if ! $KCADM get authentication/flows -r "$REALM" > "$FLOW_FILE" 2>/dev/null; then
  echo "[WARN] '-r' flag failed; trying '--target-realm'"
  $KCADM get authentication/flows --target-realm "$REALM" > "$FLOW_FILE"
fi

# Show first few lines
echo "[DEBUG] First few lines of $FLOW_FILE:"
head -n 5 "$FLOW_FILE" || echo "[WARN] file empty"

# Extract alias and id pairs for debugging
if grep -q '"alias"' "$FLOW_FILE"; then
  echo "[INFO] Found aliases:"
  grep -o '"alias":"[^"]*"' "$FLOW_FILE"
else
  echo "[ERROR] No aliases found — verify your KCADM command or login session."
  exit 1
fi

# Now extract ID
FLOW_ID=$(sed -n "s/.*\"id\":\"\([^\"]*\)\".*\"alias\":\"$FLOW_ALIAS\".*/\1/p" "$FLOW_FILE")
if [ -z "$FLOW_ID" ]; then
  echo " Could not find flow ID for '$FLOW_ALIAS'."
  exit 1
fi

echo " FLOW_ID=$FLOW_ID"

# -----------------------------
# 5️ Add Execution: X509 Validate Username
# -----------------------------
echo " Adding execution '$EXECUTION_PROVIDER' to flow '$FLOW_ALIAS'..."
$KEYCLOAK_BIN create authentication/flows/$FLOW_ALIAS/executions/execution -r "$REALM" \
  -s provider="$EXECUTION_PROVIDER" || echo " Execution may already exist."

# -----------------------------
# 6️ Get Execution ID
# -----------------------------
echo " Fetching execution ID..."
EXECUTIONS=$($KEYCLOAK_BIN get authentication/flows/$FLOW_ALIAS/executions -r "$REALM")
EXEC_ID=$(echo "$EXECUTIONS" | sed -n "/\"providerId\":\"$EXECUTION_PROVIDER\"/s/.*\"id\":\"\([^\"]*\)\".*/\1/p" | head -n1)

if [ -z "$EXEC_ID" ]; then
  echo " Could not find execution ID for $EXECUTION_PROVIDER"
  exit 1
fi

echo " EXECUTION_ID=$EXEC_ID"

# -----------------------------
# 7️ Set Execution Requirement
# -----------------------------
echo " Setting execution requirement to REQUIRED..."
$KEYCLOAK_BIN update authentication/executions/$EXEC_ID/config -r "$REALM" -s requirement=REQUIRED || \
$KEYCLOAK_BIN update authentication/executions/$EXEC_ID -r "$REALM" -s requirement=REQUIRED

# -----------------------------
# 8️ Verify Configuration
# -----------------------------
echo " Verifying '$FLOW_ALIAS' configuration..."
$KEYCLOAK_BIN get authentication/flows/$FLOW_ALIAS/executions -r "$REALM"

echo " Authentication flow '$FLOW_ALIAS' with X509/Validate Username created successfully!"

# Escape sed special characters
SAFE_URL=$(printf '%s' "$NEW_URL" | sed -e 's/[\/&]/\\&/g')

# Use sed with alternate delimiter to avoid slash issues
# Matches the "connectionUrl": ["..."] pattern safely
sed -i "s|\"connectionUrl\": *\[\"[^\"]*\"\]|\"connectionUrl\": [\"$SAFE_URL\"]|" "$JSON_FILE"


##================================================================
#!/bin/bash
# Usage: ./update_json_url.sh path/to/json_file.json
JSON_FILE="$1"

#!/bin/bash

# Usage: ./update_connection_url.sh path/to/json_file.json

JSON_FILE="$1"

if [[ -z "$JSON_FILE" ]]; then
  echo "❌ Usage: $0 path/to/json_file.json"
  exit 1
fi

if [[ ! -f "$JSON_FILE" ]]; then
  echo "❌ File not found: $JSON_FILE"
  exit 1
fi

# Extract the connectionUrl value (first entry)
CONN_URL=$(grep -o '"connectionUrl"[[:space:]]*:[[:space:]]*\[[[:space:]]*"[^"]*"' "$JSON_FILE" | sed -E 's/.*"connectionUrl"[[:space:]]*:[[:space:]]*\[[[:space:]]*"([^"]*)".*/\1/')

if [[ -z "$CONN_URL" ]]; then
  echo "❌ Could not find connectionUrl in $JSON_FILE"
  exit 1
fi

# Remove the first 7 characters ("ldap://")
MODIFIED_URL="${CONN_URL:7}"

echo "Original: $CONN_URL"
echo "Modified: $MODIFIED_URL"

# Replace the connectionUrl value inline (keeping JSON formatting)
sed -i.bak "s#\"connectionUrl\"[[:space:]]*:[[:space:]]*\[[[:space:]]*\"[^\"]*\"#\"connectionUrl\": [\"${MODIFIED_URL}\"#g" "$JSON_FILE"

echo "✅ Updated $JSON_FILE successfully."

# Replace NEW_URL value in the JSON file (inline)
# Use sed to safely replace the value, keeping the rest of the JSON untouched
# sed -i.bak "s#\"NEW_URL\"[[:space:]]*:[[:space:]]*\"[^\"]*\"#\"NEW_URL\": \"${MODIFIED_URL}\"#g" "$JSON_FILE"

echo "✅ Updated $JSON_FILE successfully."


##===================================================================================
#!/bin/bash

# Usage: ./update_connection_url_keep_prefix.sh path/to/json_file.json new_host_value
# Example: ./update_connection_url_keep_prefix.sh config.json "dev-ldap-dns.us.com:636"

JSON_FILE="$1"
NEW_VALUE="$2"

if [[ -z "$JSON_FILE" || -z "$NEW_VALUE" ]]; then
  echo "❌ Usage: $0 path/to/json_file.json new_host_value"
  exit 1
fi

if [[ ! -f "$JSON_FILE" ]]; then
  echo "❌ File not found: $JSON_FILE"
  exit 1
fi

# Extract the current connectionUrl value (first entry in the array)
CURRENT_URL=$(grep -o '"connectionUrl"[[:space:]]*:[[:space:]]*\[[[:space:]]*"[^"]*"' "$JSON_FILE" \
  | sed -E 's/.*"connectionUrl"[[:space:]]*:[[:space:]]*\[[[:space:]]*"([^"]*)".*/\1/')

if [[ -z "$CURRENT_URL" ]]; then
  echo "❌ Could not find connectionUrl in $JSON_FILE"
  exit 1
fi

# Extract prefix ("ldap://") and the rest of the URL
PREFIX="${CURRENT_URL:0:7}"
OLD_REST="${CURRENT_URL:7}"

echo "Current URL: $CURRENT_URL"
echo "Prefix kept: $PREFIX"
echo "Old rest: $OLD_REST"
echo "New rest: $NEW_VALUE"

# Construct the new URL
UPDATED_URL="${PREFIX}${NEW_VALUE}"

echo "✅ Final URL will be: $UPDATED_URL"

# Replace only the connectionUrl value in JSON (in-place)
sed -i.bak "s#\"connectionUrl\"[[:space:]]*:[[:space:]]*\[[[:space:]]*\"[^\"]*\"#\"connectionUrl\": [\"${UPDATED_URL}\"#g" "$JSON_FILE"

echo "✅ Updated $JSON_FILE successfully."
