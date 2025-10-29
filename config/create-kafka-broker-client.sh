#!/bin/bash
set -e

# ===========================================
# Usage:
#   ./create-kafka-broker-client.sh <REALM_NAME>
# Example:
#   ./create-kafka-broker-client.sh myrealm
# ===========================================
# === Parameters ===
if [ $# -lt 4 ]; then
  echo "Usage: $0 <KEYCLOAK_URL> <REALM> <ADMIN_USER> <ADMIN_PASS>"
  exit 1
fi

KEYCLOAK_URL=$1
REALM=$2
ADMIN_USER=$3
ADMIN_PASS=$4

# if [[ -z "$REALM" ]]; then
#   echo "Usage: $0 <REALM_NAME>"
#   exit 1
# fi

# ---- Keycloak config ----
KCADM="/opt/keycloak/bin/kcadm.sh"
KCADM_CONFIG="/tmp/kcadm.config"

# KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8080}"
# ADMIN_USER="${ADMIN_USER:-admin}"
# ADMIN_PASS="${ADMIN_PASS:-admin}"
# MASTER_REALM="${MASTER_REALM:-master}"

# ---- Login ----
echo " Logging into Keycloak..."
$KCADM config credentials \
  --config "$KCADM_CONFIG" \
  --server "$KEYCLOAK_URL" \
  --realm "$MASTER_REALM" \
  --user "$ADMIN_USER" \
  --password "$ADMIN_PASS"

# ---- Check if client already exists ----
EXISTING_CLIENT=$($KCADM get clients -r "$REALM" --config "$KCADM_CONFIG" --fields clientId | grep '"clientId" : "kafka-broker"' || true)
if [[ -n "$EXISTING_CLIENT" ]]; then
  echo " Client 'kafka-broker' already exists in realm '$REALM'. Skipping creation."
  exit 0
fi

# ---- Create client ----
echo " Creating client 'kafka-broker'..."
$KCADM create clients -r "$REALM" --config "$KCADM_CONFIG" -f - <<EOF
{
  "clientId": "kafka-broker",
  "enabled": true,
  "publicClient": false,
  "directAccessGrantsEnabled": true,
  "serviceAccountsEnabled": true,
  "authorizationServicesEnabled": true,
  "protocol": "openid-connect",
  "standardFlowEnabled": false,
  "implicitFlowEnabled": false,
  "bearerOnly": false,
  "clientAuthenticatorType": "client-secret",
  "attributes": {
    "access.token.lifespan": "3600"
  }
}
EOF


##### OR
echo ">>> Creating Kafka Broker client in realm: $REALM"
$KCADM create clients --config "$CONFIG_FILE" -r "$REALM" -s clientId="kafka-broker" \
  -s enabled=true \
  -s 'redirectUris=["*"]' \
  -s 'webOrigins=["*"]' \
  -s publicClient=false \
  -s serviceAccountsEnabled=true \
  -s directAccessGrantsEnabled=true \
  -s authorizationServicesEnabled=true \
  -s protocol="openid-connect"

echo ">>> Client 'kafka-broker' created successfully in realm '$REALM'."
##### 

# ---- Get created client ID ----
CLIENT_ID=$($KCADM get clients -r "$REALM" --config "$KCADM_CONFIG" --fields id,clientId | grep -A1 '"clientId" : "kafka-broker"' | grep '"id"' | sed 's/.*: "\(.*\)".*/\1/')

# ---- (Optional) Associate with Authentication Flow ----
# "Direct Access Grants" is built-in, but if you want to explicitly bind it:
echo " Ensuring client allows Direct Access Grants flow..."
$KCADM update clients/"$CLIENT_ID" -r "$REALM" --config "$KCADM_CONFIG" -s directAccessGrantsEnabled=true

echo " Client 'kafka-broker' created successfully in realm '$REALM'"
