#!/bin/bash
set -e

# === Usage ===
if [ $# -lt 4 ]; then
  echo "Usage: $0 <KEYCLOAK_URL> <REALM> <ADMIN_USER> <ADMIN_PASS>"
  exit 1
fi

KEYCLOAK_URL=$1
REALM=$2
ADMIN_USER=$3
ADMIN_PASS=$4

KCADM="/opt/keycloak/bin/kcadm.sh"
CONFIG_FILE="/tmp/kcadm.config"
CLIENT_ID="secure-client"

echo ">>> Logging into Keycloak at $KEYCLOAK_URL ..."
$KCADM config credentials --config "$CONFIG_FILE" \
  --server "$KEYCLOAK_URL" \
  --realm master \
  --user "$ADMIN_USER" \
  --password "$ADMIN_PASS"

echo ">>> Checking if client '$CLIENT_ID' exists in realm '$REALM' ..."
CLIENT_UUID=$($KCADM get clients --config "$CONFIG_FILE" -r "$REALM" --fields id,clientId | jq -r ".[] | select(.clientId==\"$CLIENT_ID\") | .id")

if [ -z "$CLIENT_UUID" ]; then
  echo ">>> Creating client '$CLIENT_ID' with Authorization enabled ..."
  $KCADM create clients --config "$CONFIG_FILE" -r "$REALM" \
    -s clientId="$CLIENT_ID" \
    -s enabled=true \
    -s protocol="openid-connect" \
    -s serviceAccountsEnabled=true \
    -s publicClient=false \
    -s authorizationServicesEnabled=true \
    -s directAccessGrantsEnabled=true \
    -s 'redirectUris=["*"]' \
    -s 'webOrigins=["*"]'
  
  # Get the new client's UUID
#   CLIENTS_JSON=$($KCADM get clients --config "$CONFIG_FILE" -r "$REALM" --fields id,clientId)
#   CLIENT_UUID=$(echo "$CLIENTS_JSON" | grep -A1 "\"clientId\" : \"$CLIENT_ID\"" | grep '"id"' | sed 's/.*"id" : "\(.*\)".*/\1/' | tr -d '\r')
  CLIENT_UUID=$($KCADM get clients --config "$CONFIG_FILE" -r "$REALM" --fields id,clientId | jq -r ".[] | select(.clientId==\"$CLIENT_ID\") | .id")
  echo ">>> Client created with ID: $CLIENT_UUID"
else
  echo ">>> Client '$CLIENT_ID' already exists with ID: $CLIENT_UUID"
fi

echo ">>> Updating Authorization Settings ..."
$KCADM update clients/$CLIENT_UUID/authz/resource-server --config "$CONFIG_FILE" -r "$REALM" \
  -s policyEnforcementMode="ENFORCING" \
  -s decisionStrategy="UNANIMOUS" \
  -s remoteResourceManagement=true

echo "✅ Client '$CLIENT_ID' authorization configured:"
echo "   Policy Enforcement Mode: ENFORCING"
echo "   Decision Strategy: UNANIMOUS"
echo "   Remote Resource Management: ON"
