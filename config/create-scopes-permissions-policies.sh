#!/bin/bash
# Usage: ./create-scopes-and-policies.sh <realm> <admin_user> <admin_pass>
# Example: ./create-scopes-and-policies.sh realm admin password

set -e

REALM=$1
ADMIN_USER=$2
ADMIN_PASS=$3
CLIENT_ID="kafka-broker"

KEYCLOAK_URL="http://localhost:8080/auth"
KC="$KEYCLOAK_HOME/bin/kcadm.sh"

# Login as admin
$KC config credentials --server $KEYCLOAK_URL --realm master --user "$ADMIN_USER" --password "$ADMIN_PASS"

# Get client UUID
CLIENT_UUID=$($KC get clients -r "$REALM" -q clientId=$CLIENT_ID --fields id --format csv | tail -n 1)

if [[ -z "$CLIENT_UUID" ]]; then
  echo " Client '$CLIENT_ID' not found in realm '$REALM'"
  exit 1
fi
echo "Using CLIENT_UUID: $CLIENT_UUID"

# ========== CREATE SCOPES ==========
create_scope() {
  local name="$1"
  local display_name="$2"
  echo "→ Creating scope: $name"
  $KC create clients/$CLIENT_UUID/authz/resource-server/scope -r "$REALM" \
    -s name="$name" -s displayName="$display_name" >/dev/null || true
}

SCOPES=(Alter AlterConfig ClusterAction Create Delete Describe DescribeConfigs Write)
# for S in "${SCOPES[@]}"; do
#   create_scope "$S" "$S"
# done
for SCOPE in "${SCOPES[@]}"; do
  echo " Ensuring scope '$SCOPE' exists..."
  EXIST=$($KC get clients/$CLIENT_UUID/authz/resource-server/scope -r "$REALM" --config "$CONFIG_FILE" | grep -c "\"name\" : \"$SCOPE\"") || true
  if [ "$EXIST" -eq 0 ]; then
    $KC create clients/$CLIENT_UUID/authz/resource-server/scope -r "$REALM" --config "$CONFIG_FILE" -s name="$SCOPE" >/dev/null
    echo " Created scope: $SCOPE"
  else
    echo " Scope '$SCOPE' already exists."
  fi
done
echo " Authorization scopes created."

# ========== GET RESOURCE IDs ==========
# TOPIC_RESOURCE_ID=$($KC get clients/$CLIENT_UUID/authz/resource-server/resource -r "$REALM" \
#   --fields id,name --format csv | grep "topic:demo-topic" | cut -d, -f1)
# CLUSTER_RESOURCE_ID=$($KC get clients/$CLIENT_UUID/authz/resource-server/resource -r "$REALM" \
#   --fields id,name --format csv | grep "cluster:*" | cut -d, -f1)

# Get the resource list (JSON)
RESOURCE_LIST=$($KCADM get clients/$CLIENT_UUID/authz/resource-server/resource -r "$REALM" --config "$CONFIG_FILE")
echo "RESOURCE_LIST: $RESOURCE_LIST"

# Extract topic:demo-topic resource ID safely without jq
# Get all resources from the client
RESOURCE_JSON=$($KCADM get clients/$CLIENT_UUID/authz/resource-server/resource \
  -r "$REALM" --config "$CONFIG_FILE")

# Extract resource ID for topic:demo-topic (no jq/awk)
# TOPIC_RESOURCE_ID=$(echo "$RESOURCE_JSON" | \
#   tr -d '\r' | \
#   sed -n '/"name" : "topic:demo-topic"/,/}/p' | \
#   grep '"id"' | \
#   sed 's/.*: "\(.*\)".*/\1/' | head -1)

RESOURCE_LIST='[
  {
    "name" : "cluster:*",
    "_id" : "12312423423"
  },
  {
    "name" : "topic:demo-topic",
    "_id" : "9999999999"
  }
]'

# Remove newlines, tabs, and spaces for simpler parsing
CLEAN_JSON=$(echo "$RESOURCE_LIST" | tr -d '\n\t ')

# Extract the "_id" value only for "cluster:*"
ID_VALUE=$(echo "$CLEAN_JSON" | sed -n 's/.*"name":"cluster:\*","_id":"\([^"]*\)".*/\1/p')

echo "Cluster ID: $ID_VALUE"

if [ -z "$TOPIC_RESOURCE_ID" ]; then
  echo " Resource 'topic:demo-topic' not found!"
  exit 1
else
  echo " Found topic resource ID: $TOPIC_RESOURCE_ID"
fi

# TOPIC_RESOURCE_ID=$(echo "$RESOURCE_LIST" | awk '/"name" : "topic:demo-topic"/ {getline; if ($1=="\"id\"") {gsub("[\",]", "", $3); print $3; exit}}')
# CLUSTER_RESOURCE_ID=$(echo "$RESOURCE_LIST" | awk '/"name" : "cluster:*"/ {getline; if ($1=="\"id\"") {gsub("[\",]", "", $3); print $3; exit}}')

if [ -z "$TOPIC_RESOURCE_ID" ]; then
  echo " Error: Could not find resource 'topic:demo-topic'"
  exit 1
else
  echo " Found resource ID for topic:demo-topic = $TOPIC_RESOURCE_ID"
fi

if [[ -z "$TOPIC_RESOURCE_ID" || -z "$CLUSTER_RESOURCE_ID" ]]; then
  echo " Resource IDs missing — make sure 'topic:demo-topic' and 'cluster:*' exist."
  exit 1
fi


# ========== CREATE PERMISSIONS ==========
create_permission() {
  local name="$1"
  local resource_id="$2"
  local scope="$3"

  echo "→ Creating permission: $name"
  $KC create clients/$CLIENT_UUID/authz/resource-server/permission/scope \
    -r "$REALM" \
    -s name="$name" \
    -s decisionStrategy="UNANIMOUS" \
    -s logic="POSITIVE" \
    -s resources="[\"$resource_id\"]" \
    -s scopes="[\"$scope\"]" >/dev/null || true
}

create_permission "topic:demo-topic:Alter" "$TOPIC_RESOURCE_ID" "Alter"
create_permission "cluster:dev:AlterConfig" "$CLUSTER_RESOURCE_ID" "AlterConfig"
create_permission "cluster:dev:ClusterAction" "$CLUSTER_RESOURCE_ID" "ClusterAction"
create_permission "topic:demo-topic:Create" "$TOPIC_RESOURCE_ID" "Create"
create_permission "topic:demo-topic:Delete" "$TOPIC_RESOURCE_ID" "Delete"
create_permission "topic:demo-topic:Describe" "$TOPIC_RESOURCE_ID" "Describe"
create_permission "topic:demo-topic:DescribeConfigs" "$TOPIC_RESOURCE_ID" "DescribeConfigs"
create_permission "topic:demo-topic:Write" "$TOPIC_RESOURCE_ID" "Write"

echo " Permissions created."

# ========== CREATE POLICIES ==========
create_group_policy() {
  local policy_name="$1"
  local group_name="$2"
  local logic="$3"

  # Get group ID
  GROUP_ID=$($KC get groups -r "$REALM" --fields id,name,path --format csv | grep "$group_name" | cut -d, -f1)
  if [[ -z "$GROUP_ID" ]]; then
    echo " Group '$group_name' not found — skipping policy '$policy_name'"
    return
  fi
-----------------------
# Get the raw list of groups from Keycloak
GROUPS_OUTPUT=$($KCADM get groups -r "$REALM" --fields id,name,path --format csv 2>/dev/null)

# Remove carriage returns, quotes, and spaces
GROUPS_CLEAN=$(echo "$GROUPS_OUTPUT" | tr -d '\r' | sed 's/"//g')

# Search for the group name in the "path" column and extract the first field (id)
GROUP_ID=$(echo "$GROUPS_CLEAN" | while IFS=, read -r id name path; do
  if [ "$path" = "$group_name" ]; then
    echo "$id"
    break
  fi
done)

if [ -n "$GROUP_ID" ]; then
  echo " Found group '$group_name' with ID: $GROUP_ID"
else
  echo " Group '$group_name' not found in realm '$REALM'"
fi

----------------------
  echo "→ Creating policy: $policy_name (Group: $group_name)"
  $KC create clients/$CLIENT_UUID/authz/resource-server/policy/group \
    -r "$REALM" \
    -s name="$policy_name" \
    -s logic="$logic" \
    -s decisionStrategy="UNANIMOUS" \
    -s groups="[{'id':'$GROUP_ID','path':'$group_name'}]" >/dev/null || true
}

create_group_policy "topic-ro-policy" "/dev-topic-ro" "POSITIVE"
create_group_policy "topic-wo-policy" "/dev-topic-wo" "POSITIVE"

echo " Group-based authorization policies created successfully."
--------------
# --- UPDATE PERMISSION SCOPES ---
echo " Updating 'cluster-access' permission scopes ..."

# Define desired scopes
SCOPES_TO_ATTACH='["AlterConfig","ClusterAction","DescribeConfigs"]'

# Get the permission ID for 'cluster-access'
PERMISSION_ID=$($KC get clients/$CLIENT_UUID/authz/resource-server/permission/resource \
  -r "$REALM" --config "$CONFIG_FILE" | grep -B1 '"name" : "cluster-access"' | grep '"id"' | sed 's/.*"id" : "\(.*\)".*/\1/' | tr -d '[:space:]')

if [ -z "$PERMISSION_ID" ]; then
  echo " Could not find 'cluster-access' permission in realm '$REALM'."
else
  echo " Found Permission ID: $PERMISSION_ID"
  echo "  Updating scopes → $SCOPES_TO_ATTACH"

  $KC update clients/$CLIENT_UUID/authz/resource-server/permission/resource/$PERMISSION_ID \
    --config "$CONFIG_FILE" -r "$REALM" \
    -s scopes="$SCOPES_TO_ATTACH" >/dev/null \
    && echo " 'cluster-access' permission scopes updated." \
    || echo " Failed to update permission scopes."
fi



-----------------------------
# --- Ensure Scopes Exist ---
SCOPES=("AlterConfig" "ClusterAction" "DescribeConfigs" "Read" "Write")

for SCOPE in "${SCOPES[@]}"; do
  echo " Ensuring scope '$SCOPE' exists..."
  EXIST=$($KC get clients/$CLIENT_UUID/authz/resource-server/scope -r "$REALM" --config "$CONFIG_FILE" | grep -c "\"name\" : \"$SCOPE\"") || true
  if [ "$EXIST" -eq 0 ]; then
    $KC create clients/$CLIENT_UUID/authz/resource-server/scope -r "$REALM" --config "$CONFIG_FILE" -s name="$SCOPE" >/dev/null
    echo " Created scope: $SCOPE"
  else
    echo " Scope '$SCOPE' already exists."
  fi
done

# --- Create Permissions ---
create_permission() {
  local NAME=$1
  local SCOPES_JSON=$2
  echo " Creating permission '$NAME' with scopes $SCOPES_JSON..."
  $KC create clients/$CLIENT_UUID/authz/resource-server/permission/scope \
    --config "$CONFIG_FILE" -r "$REALM" \
    -s name="$NAME" \
    -s type="scope" \
    -s decisionStrategy="UNANIMOUS" \
    -s scopes="$SCOPES_JSON" >/dev/null 2>&1 \
    && echo " Permission '$NAME' created." \
    || echo " Permission '$NAME' may already exist."
}

create_permission "cluster-access" '["AlterConfig","ClusterAction","DescribeConfigs"]'
create_permission "topic-access-read" '["Read"]'
create_permission "topic-access-write" '["Write"]'

echo " All permissions created for '$CLIENT_ID'."

echo " Summary:"
echo "  Realm: $REALM"
echo "  Client: $CLIENT_ID"
echo "  Permissions:"
echo "    - cluster-access → [AlterConfig, ClusterAction, DescribeConfigs]"
echo "    - topic-access-read → [Read]"
echo "    - topic-access-write → [Write]"