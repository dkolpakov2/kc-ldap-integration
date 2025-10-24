#!/bin/bash

# --- CONFIG ---
KC_ADMIN="/opt/keycloak/bin/kcadm.sh"
KC_URL="http://localhost:8080"
REALM="kafka-dev"
FLOW_ALIAS="kafka-direct-grant"
PROVIDER="x509-username"
REQUIREMENT="REQUIRED"

# --- LOGIN ---
$KC_ADMIN config credentials --server "$KC_URL" --realm master --user admin --password admin

# --- Ensure flow exists ---
echo "Checking if flow '$FLOW_ALIAS' exists..."
FLOW_ID=$($KC_ADMIN get authentication/flows -r "$REALM" | grep -B2 "\"alias\" : \"$FLOW_ALIAS\"" | grep "\"id\" :" | sed 's/.*: "\(.*\)".*/\1/')

if [ -z "$FLOW_ID" ]; then
  echo "Flow not found. Creating '$FLOW_ALIAS'..."
  $KC_ADMIN create authentication/flows -r "$REALM" \
    -s alias="$FLOW_ALIAS" \
    -s description="Custom grant flow for Kafka" \
    -s providerId=basic-flow \
    -s topLevel=true \
    -s builtIn=false
  echo "Flow created."
fi

# --- Add execution ---
echo "Adding execution for provider '$PROVIDER'..."
$KC_ADMIN create "authentication/flows/$FLOW_ALIAS/executions/execution" -r "$REALM" \
  -s provider="$PROVIDER"

# --- Set requirement ---
echo "Setting requirement to $REQUIREMENT..."
$KC_ADMIN update "authentication/flows/$FLOW_ALIAS/executions" -r "$REALM" \
  -s requirement="$REQUIREMENT"

echo "✅ X.509 execution successfully added to flow '$FLOW_ALIAS'"

PROVIDER_ID="auth-x509-client-username-form"
JSON_FILE="executions.json"
# Read file content and normalize
JSON=$(cat "$JSON_FILE" | tr -d '\n' | sed 's/},/},\n/g')

# Extract ID for the given providerId
EXEC_ID=$(echo "$JSON" | grep "$PROVIDER_ID" -B5 | grep '"id"' | sed 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

echo "Execution ID for providerId '$PROVIDER_ID' is: $EXEC_ID"