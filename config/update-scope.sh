#!/bin/bash

# --- Parameters ---
REALM="ess-kafka"
CLIENT_ID="kafka-broker"
SCOPE_NAME="ClusterAction"
SCOPES="cluster:dev:create,cluster:dev:read,cluster:dev:update"
RESOURCE_NAME="cluster:*"
PERMISSION_NAME="cluster-admin-permission"
CONFIG_FILE="/tmp/kcadm.config"
KCADM="/opt/keycloak/bin/kcadm.sh --config $CONFIG_FILE"

SCOPES_JSON="[$(
  echo "$SCOPES" \
    | sed 's/,/", "/g' \
    | sed 's/^/"/; s/$/"/' \
    | sed 's/"/\\"/g'
)]"

echo "$SCOPES_JSON"
## OUTPUT: [\"cluster:dev:create\", \"cluster:dev:read\", \"cluster:dev:update\"]

RESOURCE_NAME="cluster/dev/resource1"
CLIENT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
REALM="dev"
CONFIG_FILE="/path/to/kcadm.config"

# Query resources
RESOURCE_ID=$(
  kcadm.sh get "clients/$CLIENT_ID/authz/resource-server/resource" \
    --config "$CONFIG_FILE" -r "$REALM" \
    | jq -r ".[] | select(.name == \"$RESOURCE_NAME\") | ._id"
)

if [[ -n "$RESOURCE_ID" && "$RESOURCE_ID" != "null" ]]; then
    echo "Resource FOUND: $RESOURCE_ID"
else
    echo "Resource NOT FOUND"
fi

echo " Finding client UUID for '$CLIENT_ID'..."
CLIENT_UUID=$($KCADM get clients -r "$REALM" --fields id,clientId \
  | grep -B1 "\"clientId\" : \"$CLIENT_ID\"" | grep '"id"' | sed -E 's/.*"id" : "(.*)".*/\1/' | tr -d '[:space:]')

if [ -z "$CLIENT_UUID" ]; then
  echo " Client '$CLIENT_ID' not found in realm '$REALM'"
  exit 1
fi

echo " Client UUID: $CLIENT_UUID"

# --- Get resource ID for cluster:* ---
echo " Looking up resource '$RESOURCE_NAME'..."
RESOURCE_ID=$($KCADM get clients/$CLIENT_UUID/authz/resource-server/resource -r "$REALM" \
  | tr -d '\n\t\r ' | sed -n "s/.*\"name\":\"$RESOURCE_NAME\"[^}]*\"_id\":\"\([^\"]*\)\".*/\1/p")

if [ -z "$RESOURCE_ID" ]; then
  echo " Resource '$RESOURCE_NAME' not found."
  exit 1
fi

echo " Resource ID: $RESOURCE_ID"

# --- Get scope ID for ClusterAction ---
echo " Looking up scope '$SCOPE_NAME'..."
SCOPE_ID=$($KCADM get clients/$CLIENT_UUID/authz/resource-server/scope -r "$REALM" \
  | tr -d '\n\t\r ' | sed -n "s/.*\"name\":\"$SCOPE_NAME\"[^}]*\"id\":\"\([^\"]*\)\".*/\1/p")

if [ -z "$SCOPE_ID" ]; then
  echo " Scope '$SCOPE_NAME' not found."
  exit 1
fi

echo " Scope ID: $SCOPE_ID"

# --- Get permission ID ---
echo " Looking up permission '$PERMISSION_NAME'..."
PERM_ID=$($KCADM get clients/$CLIENT_UUID/authz/resource-server/permission/resource -r "$REALM" \
  | tr -d '\n\t\r ' | sed -n "s/.*\"name\":\"$PERMISSION_NAME\"[^}]*\"id\":\"\([^\"]*\)\".*/\1/p")


if [ -z "$PERM_ID" ]; then
  echo " Permission '$PERMISSION_NAME' not found. Creating new permission..."
  $KCADM create clients/$CLIENT_UUID/authz/resource-server/permission/resource -r "$REALM" \
    -s name="$PERMISSION_NAME" \
    -s resources="[\"$RESOURCE_NAME\"]" \
    -s scopes="[\"$SCOPE_NAME\"]" \
    -s decisionStrategy="UNANIMOUS"
else
  echo " Permission found: $PERM_ID — updating..."
  $KCADM update clients/$CLIENT_UUID/authz/resource-server/permission/resource/$PERM_ID -r "$REALM" \
    -s resources="[\"$RESOURCE_NAME\"]" \
    -s scopes="[\"$SCOPE_NAME\"]"
fi

echo "Updated permission '$PERMISSION_NAME' to link scope '$SCOPE_NAME' with resource '$RESOURCE_NAME'."
