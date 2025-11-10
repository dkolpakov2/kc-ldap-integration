#!/bin/bash
set -e

# ====== CONFIG ======
REALM="ess-kafka"
CLIENT_NAME="kafka-broker"
PERMISSION_NAME="cluster-admin-permission"
POLICY_NAME="dev-cluster-admin"
CONFIG_FILE="/path/to/kcadm.config"  # path to your admin config file
KCADM="/opt/keycloak/bin/kcadm.sh"   # adjust if needed

# ====== FETCH CLIENT UUID ======
CLIENT_UUID=$($KCADM get clients -r "$REALM" --config "$CONFIG_FILE" --fields id,clientId --format csv | grep ",$CLIENT_NAME" | cut -d, -f1)

if [ -z "$CLIENT_UUID" ]; then
  echo " Client '$CLIENT_NAME' not found in realm '$REALM'"
  exit 1
fi

# ====== FETCH PERMISSION ID ======
PERMISSION_ID=$($KCADM get clients/$CLIENT_UUID/authz/resource-server/permission/resource \
  -r "$REALM" --config "$CONFIG_FILE" --fields id,name --format csv | grep ",$PERMISSION_NAME" | cut -d, -f1)

if [ -z "$PERMISSION_ID" ]; then
  echo " Permission '$PERMISSION_NAME' not found."
  exit 1
fi

# ====== FETCH POLICY ID ======
POLICY_ID=$($KCADM get clients/$CLIENT_UUID/authz/resource-server/policy \
  -r "$REALM" --config "$CONFIG_FILE" --fields id,name --format csv | grep ",$POLICY_NAME" | cut -d, -f1)

if [ -z "$POLICY_ID" ]; then
  echo " Policy '$POLICY_NAME' not found."
  exit 1
fi

# ====== CLEAN QUOTES (if any) ======
PERMISSION_ID=${PERMISSION_ID//\"/}
POLICY_ID=${POLICY_ID//\"/}

# ====== ASSOCIATE POLICY TO PERMISSION ======
echo " Associating policy '$POLICY_NAME' with permission '$PERMISSION_NAME'..."

$KCADM update clients/$CLIENT_UUID/authz/resource-server/permission/resource/$PERMISSION_ID \
  -r "$REALM" --config "$CONFIG_FILE" \
  -s "policies=[\"$POLICY_ID\"]"

echo " Successfully associated '$POLICY_NAME' → '$PERMISSION_NAME'"