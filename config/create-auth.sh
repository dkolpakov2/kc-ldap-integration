#!/usr/bin/env bash
set -e

### -----------------------------
### CONFIGURATION
### -----------------------------
KC_URL="https://keycloak-001-dns.com"
KC_REALM="master"
KC_USER="admin"
KC_PASS="Adminu\$er"   # escape $ in bash
CLIENT_ID="your-client-id"

# Resource and scopes
RESOURCE_NAME="topic:test-payment"
SCOPES=("Write" "Read" "Describe")

# Policies
POLICY_WO="test-payment-wo-policy"
POLICY_RO="test-payment-ro-policy"

# Permissions
PERMISSION_WO="topic:test-payment:wo-permission"
PERMISSION_RO="topic:test-payment:ro-permission"
### -----------------------------


echo "=== 1. Obtaining access token ==="
TOKEN_RESPONSE=$(curl -s -X POST "$KC_URL/realms/$KC_REALM/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$KC_USER" \
  -d "password=$KC_PASS" \
  -d "grant_type=password" \
  -d "client_id=admin-cli")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')

if [ -z "$ACCESS_TOKEN" ]; then
  echo "ERROR: Failed to get token"
  exit 1
fi


echo "=== 2. Get client UUID ==="
CLIENT_LOOKUP=$(curl -s -X GET "$KC_URL/admin/realms/$KC_REALM/clients?clientId=$CLIENT_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

CLIENT_UUID=$(echo "$CLIENT_LOOKUP" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')

if [ -z "$CLIENT_UUID" ]; then
  echo "ERROR: Client not found"
  exit 1
fi


echo "=== 3. Create resource type=scope with scopes ==="
# Build scopes JSON manually
SCOPES_JSON=""
for S in "${SCOPES[@]}"; do
  SCOPES_JSON="$SCOPES_JSON\"$S\","
done
SCOPES_JSON="[${SCOPES_JSON%,}]"

RESOURCE_RESPONSE=$(curl -s -X POST \
  "$KC_URL/admin/realms/$KC_REALM/clients/$CLIENT_UUID/authz/resource-server/resource" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"$RESOURCE_NAME\",
    \"type\": \"scope\",
    \"ownerManagedAccess\": false,
    \"scopes\": $SCOPES_JSON,
    \"uris\": [\"$RESOURCE_NAME\"]
  }")

RESOURCE_ID=$(echo "$RESOURCE_RESPONSE" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')

if [ -z "$RESOURCE_ID" ]; then
  echo "ERROR: Resource creation failed"
  exit 1
fi


echo "=== 4. Create WO policy ==="
POLICY_WO_RESPONSE=$(curl -s -X POST \
  "$KC_URL/admin/realms/$KC_REALM/clients/$CLIENT_UUID/authz/resource-server/policy/role" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
     \"name\": \"$POLICY_WO\",
     \"roles\": [{
       \"id\": \"realm-admin\",
       \"required\": false
     }]
  }")

POLICY_WO_ID=$(echo "$POLICY_WO_RESPONSE" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')


echo "=== 5. Create RO policy ==="
POLICY_RO_RESPONSE=$(curl -s -X POST \
  "$KC_URL/admin/realms/$KC_REALM/clients/$CLIENT_UUID/authz/resource-server/policy/role" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
     \"name\": \"$POLICY_RO\",
     \"roles\": [{
       \"id\": \"realm-admin\",
       \"required\": false
     }]
  }")

POLICY_RO_ID=$(echo "$POLICY_RO_RESPONSE" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p")


echo "=== 6. Create WO permission and assign resource ==="
curl -s -X POST \
  "$KC_URL/admin/realms/$KC_REALM/clients/$CLIENT_UUID/authz/resource-server/permission/resource" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"$PERMISSION_WO\",
    \"resources\": [\"$RESOURCE_ID\"],
    \"policies\": [\"$POLICY_WO_ID\"]
  }" >/dev/null


echo "=== 7. Create RO permission and assign resource ==="
curl -s -X POST \
  "$KC_URL/admin/realms/$KC_REALM/clients/$CLIENT_UUID/authz/resource-server/permission/resource" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"$PERMISSION_RO\",
    \"resources\": [\"$RESOURCE_ID\"],
    \"policies\": [\"$POLICY_RO_ID\"]
  }" >/dev/null


echo "=== DONE ==="
echo "Resource ID = $RESOURCE_ID"
echo "WO Permission = $PERMISSION_WO"
echo "RO Permission = $PERMISSION_RO"
