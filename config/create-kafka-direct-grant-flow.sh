#!/bin/bash
# ============================================================
# Script: create-kafka-direct-grant-flow.sh
# Purpose: Create custom Authentication Flow "kafka-direct-grant"
#          with execution "X509/Validate Username"
# Compatible: Keycloak 21+, no jq/awk dependencies
# ============================================================

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

# -----------------------------
# 4️ Retrieve Flow ID
# -----------------------------
echo " Getting flow ID for '$FLOW_ALIAS'..."
FLOW_LIST=$($KEYCLOAK_BIN get authentication/flows -r "$REALM")
FLOW_ID=$(echo "$FLOW_LIST" | sed -n "/\"alias\":\"$FLOW_ALIAS\"/s/.*\"id\":\"\([^\"]*\)\".*/\1/p" | head -n1)

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