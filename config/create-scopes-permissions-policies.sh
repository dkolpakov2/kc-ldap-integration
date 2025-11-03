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
for S in "${SCOPES[@]}"; do
  create_scope "$S" "$S"
done
echo " Authorization scopes created."

# ========== GET RESOURCE IDs ==========
TOPIC_RESOURCE_ID=$($KC get clients/$CLIENT_UUID/authz/resource-server/resource -r "$REALM" \
  --fields id,name --format csv | grep "topic:demo-topic" | cut -d, -f1)
CLUSTER_RESOURCE_ID=$($KC get clients/$CLIENT_UUID/authz/resource-server/resource -r "$REALM" \
  --fields id,name --format csv | grep "cluster:*" | cut -d, -f1)

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