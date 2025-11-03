#!/bin/bash
set -e

# === Usage ===
#chmod +x create-client-resources.sh
# ./create-client-resources.sh https://keycloak.example.com auth-realm admin AdminPass123 kafka-broker

if [ $# -lt 5 ]; then
  echo "Usage: $0 <KEYCLOAK_URL> <REALM> <ADMIN_USER> <ADMIN_PASS> <CLIENT_ID>"
  exit 1
fi

KEYCLOAK_URL=$1
REALM=$2
ADMIN_USER=$3
ADMIN_PASS=$4
CLIENT_ID=$5

KCADM="/opt/keycloak/bin/kcadm.sh"
CONFIG_FILE="/tmp/kcadm.config"

echo ">>> Logging into Keycloak..."
$KCADM config credentials --config "$CONFIG_FILE" \
  --server "$KEYCLOAK_URL" \
  --realm master \
  --user "$ADMIN_USER" \
  --password "$ADMIN_PASS"

echo ">>> Getting client ID for '$CLIENT_ID'..."
CLIENTS_JSON=$($KCADM get clients -r "$REALM" --config "$CONFIG_FILE" --fields id,clientId)
CLIENT_UUID=$(echo "$CLIENTS_JSON" | grep -A1 "\"clientId\" : \"$CLIENT_ID\"" | grep '"id"' | sed 's/.*"id" : "\(.*\)".*/\1/' | tr -d '\r')

if [ -z "$CLIENT_UUID" ]; then
  echo "ERROR: Client '$CLIENT_ID' not found in realm '$REALM'."
  exit 1
fi
echo ">>> Client UUID: $CLIENT_UUID"

# === Enable Authorization Services ===
echo ">>> Enabling Authorization Services for client '$CLIENT_ID'..."
$KCADM update clients/$CLIENT_UUID -r "$REALM" --config "$CONFIG_FILE" \
  -s 'authorizationServicesEnabled=true' \
  -s 'serviceAccountsEnabled=true'

# === Create a Scope ===
echo ">>> Creating Scope: read"
$KCADM create clients/$CLIENT_UUID/authz/resource-server/scope \
  --config "$CONFIG_FILE" -r "$REALM" \
  -s name="read" || echo "Scope 'read' may already exist."

# === Create Resources with Type and URI ===
echo ">>> Creating Authorization Resource: cluster:*"
$KCADM create clients/$CLIENT_UUID/authz/resource-server/resource \
  --config "$CONFIG_FILE" -r "$REALM" \
  -s name="cluster:*" \
  -s displayName="cluster*" \
  -s type="urn:kafka:cluster" \
  -s uri="/cluster/*" \
  -s ownerManagedAccess=true || echo "Resource 'cluster:*' may already exist."

echo ">>> Creating Authorization Resource: topic:demo-topic"
$KCADM create clients/$CLIENT_UUID/authz/resource-server/resource \
  --config "$CONFIG_FILE" -r "$REALM" \
  -s name="topic:demo-topic" \
  -s displayName="topic:demo-topic" \
  -s description="topic:demo-topic" \
  -s type="urn:kafka:topic" \
  -s uri="/topic/demo-topic" \
  -s ownerManagedAccess=true || echo "Resource 'topic:demo-topic' may already exist."

# === Create Permissions ===
echo ">>> Creating Permission: cluster-access"
$KCADM create clients/$CLIENT_UUID/authz/resource-server/permission/resource \
  --config "$CONFIG_FILE" -r "$REALM" \
  -s name="cluster-access" \
  -s description="Allow access to cluster:*" \
  -s resources='["cluster:*"]' \
  -s scopes='["read"]' \
  -s decisionStrategy="UNANIMOUS" || echo "Permission 'cluster-access' may already exist."

echo ">>> Creating Permission: topic-access"
$KCADM create clients/$CLIENT_UUID/authz/resource-server/permission/resource \
  --config "$CONFIG_FILE" -r "$REALM" \
  -s name="topic-access" \
  -s description="Allow access to topic:demo-topic" \
  -s resources='["topic:demo-topic"]' \
  -s scopes='["read"]' \
  -s decisionStrategy="UNANIMOUS" || echo "Permission 'topic-access' may already exist."

echo " Successfully created authorization resources (with type & URI), scopes, and permissions for client '$CLIENT_ID'!"


## ===============================================
# === Create Resource 1 ===
# echo ">>> Creating Authorization Resource: cluster:*"
# $KCADM create clients/$CLIENT_UUID/authz/resource-server/resource \
#   --config "$CONFIG_FILE" -r "$REALM" \
#   -s name="cluster:*" \
#   -s displayName="cluster*" \
#   -s ownerManagedAccess=true \
#   -s owner="$CLIENT_ID"

# # === Create Resource 2 ===
# echo ">>> Creating Authorization Resource: topic:demo-topic"
# $KCADM create clients/$CLIENT_UUID/authz/resource-server/resource \
#   --config "$CONFIG_FILE" -r "$REALM" \
#   -s name="topic:demo-topic" \
#   -s displayName="topic:demo-topic" \
#   -s description="topic:demo-topic" \
#   -s ownerManagedAccess=true \
#   -s owner="$CLIENT_ID"

# echo " Successfully created authorization resources for client '$CLIENT_ID'!"
