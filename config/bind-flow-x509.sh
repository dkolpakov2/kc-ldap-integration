#!/bin/bash
set -e

# Usage
# kubectl cp bind-flow-x509.sh dev/keycloak-0:/tmp/
# kubectl exec -it keycloak-0 -n dev -- bash /tmp/bind-flow-x509.sh
# Or locally:
# export KEYCLOAK_HOME=/opt/keycloak
# bash bind-flow-x509.sh
# looking for a specific execution like “X509/Validate Username Form”, filter by authenticator:
##SELECT id, flow_id, requirement, authenticator 
#FROM authentication_execution 
#WHERE flow_id = (
#    SELECT id FROM authentication_flow WHERE alias = 'kafka-direct-grand')
#AND authenticator = 'auth-x509-username-form';


# === Configuration ===
REALM="master"
FLOW_ALIAS="kafka-direct-grand"
EXECUTION_PROVIDER="auth-x509-client-username-form"
EXECUTION_DISPLAY_NAME="X509/Validate Username Form"
# KEYCLOAK_URL="http://localhost:8080"
ADMIN_USER="admin"
ADMIN_PASS="StrongPassword123!"
ACTION="bindFlow"
KCADM="$KEYCLOAK_HOME/bin/kcadm.sh"


# === Login to Keycloak ===
echo " Logging in to Keycloak..."
$KEYCLOAK_HOME/bin/kcadm.sh config credentials \
  --server "$KEYCLOAK_URL" \
  --realm "$REALM" \
  --user "$ADMIN_USER" \
  --password "$ADMIN_PASS"

# === Verify Flow Exists ===
FLOW_EXISTS=$($KCADM get authentication/flows -r "$REALM" | grep -c "\"alias\" : \"$FLOW_ALIAS\"")
if [[ "$FLOW_EXISTS" -eq 0 ]]; then
  echo "[ERROR] Flow alias '$FLOW_ALIAS' not found in realm '$REALM'"
  exit 1
fi

echo "[INFO] Found flow alias '$FLOW_ALIAS'"

# === Add execution to flow ===
# Important: use endpoint /authentication/flows/$FLOW_ALIAS/executions/execution
ADD_OUT=$($KCADM create authentication/flows/"$FLOW_ALIAS"/executions/execution \
  -r "$REALM" \
  -s "provider=$ACTION" 2>&1 || true)

if echo "$ADD_OUT" | grep -q "parent flow does not exist"; then
  echo "[ERROR] The flow '$FLOW_ALIAS' exists but the endpoint rejected it. Double-check realm and alias spelling."
  exit 1
fi

if echo "$ADD_OUT" | grep -q "id"; then
  echo "[SUCCESS] Successfully bound execution '$ACTION' to flow '$FLOW_ALIAS'"
else
  echo "[WARN] Could not confirm success. Response:"
  echo "$ADD_OUT"
fi

#===============================================================

# === Get Flow ID ===
FLOW_ID=$($KCADM get authentication/flows -r "$REALM" --fields id,alias | \
grep -A1 "\"alias\" : \"$FLOW_ALIAS\"" | grep "\"id\"" | cut -d':' -f2 | tr -d ' ",') 

if [[ -z "$FLOW_ID" ]]; then
  echo "[ERROR] Could not find flow alias '$FLOW_ALIAS' in realm '$REALM'."
  exit 1
fi

echo "[INFO] Found flow '$FLOW_ALIAS' with ID: $FLOW_ID"

# === Bind the Flow ===
$KCADM create authentication/executions \
  -r "$REALM" \
  -s "authenticator=$ACTION" \
  -s "parentFlow=$FLOW_ALIAS" \
  -s "requirement=ALTERNATIVE" >/dev/null 2>&1

if [[ $? -eq 0 ]]; then
  echo "[SUCCESS] Action '$ACTION' successfully bound to flow '$FLOW_ALIAS'."
else
  echo "[ERROR] Failed to bind '$ACTION' to '$FLOW_ALIAS'."
  exit 1
fi


# 2nd Option  ======================================================================
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