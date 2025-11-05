#!/bin/bash
# Usage:
#   ./create-kafka-broker-client-with-scopes.sh <realm> <admin_user> <admin_pass>
#
# Example:
#   ./create-kafka-broker-client-with-scopes.sh myrealm admin admin123
set -e

REALM=$1
ADMIN_USER=$2
ADMIN_PASS=$3
CLIENT_ID="kafka-broker"

KEYCLOAK_URL="http://localhost:8080/auth"
KC="/opt/keycloak/bin/kcadm.sh"
CONFIG_FILE="/tmp/kcadm.config"

SCOPES=(Alter AlterConfig ClusterAction Create Delete Describe DescribeConfigs Write)

if [[ -z "$REALM" || -z "$ADMIN_USER" || -z "$ADMIN_PASS" ]]; then
  echo "Usage: $0 <realm> <admin_user> <admin_pass>"
  exit 1
fi

echo " Logging in as $ADMIN_USER ..."
$KC config credentials --server $KEYCLOAK_URL --realm master --user "$ADMIN_USER" --password "$ADMIN_PASS" --config "$CONFIG_FILE"

echo " Checking if client '$CLIENT_ID' exists..."
CLIENT_UUID=$($KC get clients -r "$REALM" -q clientId=$CLIENT_ID --config "$CONFIG_FILE" --fields id --format csv | tail -n 1)

if [ -n "$CLIENT_UUID" ]; then
  echo " Client '$CLIENT_ID' already exists (ID: $CLIENT_UUID)."
else
  echo " Creating client '$CLIENT_ID'..."
  $KC create clients -r "$REALM" --config "$CONFIG_FILE" \
    -s clientId="$CLIENT_ID" \
    -s enabled=true \
    -s publicClient=false \
    -s serviceAccountsEnabled=true \
    -s directAccessGrantsEnabled=true \
    -s standardFlowEnabled=true \
    -s protocol="openid-connect" \
    -s authorizationServicesEnabled=true >/dev/null
  echo " Client created."
  CLIENT_UUID=$($KC get clients -r "$REALM" -q clientId=$CLIENT_ID --config "$CONFIG_FILE" --fields id --format csv | tail -n 1)
fi

echo " Configuring Authorization (ENFORCING / AFFIRMATIVE)..."
$KC update clients/$CLIENT_UUID/authz/resource-server -r "$REALM" --config "$CONFIG_FILE" \
  -s policyEnforcementMode=ENFORCING \
  -s decisionStrategy=AFFIRMATIVE \
  -s allowRemoteResourceManagement=true >/dev/null

echo " Authorization server updated."

# --- CREATE SCOPES ---
for SCOPE in "${SCOPES[@]}"; do
  echo " Creating scope: $SCOPE ..."
  $KC create clients/$CLIENT_UUID/authz/resource-server/scope \
    -r "$REALM" --config "$CONFIG_FILE" \
    -s name="$SCOPE" \
    -s displayName="$SCOPE" >/dev/null || echo " Scope '$SCOPE' may already exist."
done

echo " All scopes created."

# --- CREATE PERMISSION ---
echo " Creating 'cluster-access' permission ..."
$KC create clients/$CLIENT_UUID/authz/resource-server/permission/resource \
  --config "$CONFIG_FILE" -r "$REALM" \
  -s name="cluster-access" \
  -s description="Allow access to cluster:*" \
  -s resources='["cluster:*"]' \
  -s decisionStrategy="UNANIMOUS" >/dev/null || echo " Permission 'cluster-access' may already exist."

echo " Authorization setup complete for '$CLIENT_ID'."

echo " Summary:"
echo "  Realm: $REALM"
echo "  Client: $CLIENT_ID"
echo "  Scopes created: ${SCOPES[*]}"
echo "  Permission: cluster-access"
