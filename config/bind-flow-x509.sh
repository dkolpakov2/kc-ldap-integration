#!/bin/bash
set -e

# === Configuration ===
REALM="master"
FLOW_ALIAS="kafka-direct-grand"
EXECUTION_PROVIDER="auth-x509-client-username-form"
EXECUTION_DISPLAY_NAME="X509/Validate Username Form"
KEYCLOAK_URL="http://localhost:8080"
ADMIN_USER="admin"
ADMIN_PASS="StrongPassword123!"

# === Login to Keycloak ===
echo " Logging in to Keycloak..."
$KEYCLOAK_HOME/bin/kcadm.sh config credentials \
  --server "$KEYCLOAK_URL" \
  --realm "$REALM" \
  --user "$ADMIN_USER" \
  --password "$ADMIN_PASS"

# === Verify flow exists ===
FLOW_ID=$($KEYCLOAK_HOME/bin/kcadm.sh get authentication/flows \
  --fields alias,id --format csv | grep "$FLOW_ALIAS" | cut -d',' -f2)

if [ -z "$FLOW_ID" ]; then
  echo " Flow '$FLOW_ALIAS' not found. Creating new flow..."
  $KEYCLOAK_HOME/bin/kcadm.sh create authentication/flows \
    -s alias="$FLOW_ALIAS" \
    -s providerId="basic-flow" \
    -s description="Custom flow for Kafka Direct Grant" \
    -s topLevel=true \
    -s builtIn=false
  echo " Flow '$FLOW_ALIAS' created."
else
  echo " Flow '$FLOW_ALIAS' already exists."
fi

# === Check if execution already exists ===
EXISTING_EXEC=$($KEYCLOAK_HOME/bin/kcadm.sh get authentication/flows/$FLOW_ALIAS/executions \
  --fields providerId,displayName --format csv | grep "$EXECUTION_PROVIDER" || true)

if [ -n "$EXISTING_EXEC" ]; then
  echo " Execution '$EXECUTION_DISPLAY_NAME' already bound to flow '$FLOW_ALIAS'. Skipping."
else
  echo " Adding execution '$EXECUTION_DISPLAY_NAME' to flow '$FLOW_ALIAS'..."
  $KEYCLOAK_HOME/bin/kcadm.sh create authentication/flows/$FLOW_ALIAS/executions/execution \
    -s provider=$EXECUTION_PROVIDER
  echo " Execution added successfully."

  echo " Setting execution requirement to 'REQUIRED'..."
  $KEYCLOAK_HOME/bin/kcadm.sh get authentication/flows/$FLOW_ALIAS/executions > /tmp/execs.json

  EXEC_ID=$(grep -B1 "$EXECUTION_PROVIDER" /tmp/execs.json | grep '"id"' | head -1 | cut -d '"' -f4)
  if [ -n "$EXEC_ID" ]; then
    $KEYCLOAK_HOME/bin/kcadm.sh update authentication/executions/$EXEC_ID \
      -s requirement=REQUIRED
    echo " Requirement set to REQUIRED."
  else
    echo " Could not find execution ID to set requirement."
  fi
fi

echo " Flow '$FLOW_ALIAS' successfully bound with execution '$EXECUTION_DISPLAY_NAME'."