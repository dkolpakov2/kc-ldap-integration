#!/usr/bin/env bash
set -e

### -----------------------------
### CONFIGURATION (EDIT THESE)
### -----------------------------
KC_URL="https://keycloak-001-dns.com"
KC_REALM="master"
KC_USER="admin-dk"
KC_PASS="Adm1nu\$er"    # escape $ in bash
CLIENT_ID="your-client-id"

# Authorization details
RESOURCE_NAME="topic:test-payment"
POLICY_NAME="test-payment-wo-policy"
PERMISSION_NAME="test-payment:wo-permission"
### -----------------------------


echo "=== 1. Getting admin token ==="
TOKEN_RESPONSE=$(curl -s -X POST "$KC_URL/realms/$KC_REALM/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$KC_USER" \
  -d "password=$KC_PASS" \
  -d "grant_type=password" \
  -d "client_id=admin-cli")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')

if [ -z "$ACCESS_TOKEN" ]; then
  echo "ERROR: Failed to obtain token"
  exit 1
fi

echo "Token obtained OK"


echo "=== 2. Getting client UUID for clientId=$CLIENT_ID ==="
CLIENT_LOOKUP=$(curl -s -X GET "$KC_URL/admin/realms/$KC_REALM/clients?clientId=$CLIENT_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

CLIENT_UUID=$(echo "$CLIENT_LOOKUP" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')

if [ -z "$CLIENT_UUID" ]; then
  echo "ERROR: Client not found!"
  exit 1
fi

echo "Client UUID = $CLIENT_UUID"


echo "=== 3. Creating resource: $RESOURCE_NAME ==="
RESOURCE_RESPONSE=$(curl -s -X POST "$KC_URL/admin/realms/$KC_REALM/clients/$CLIENT_UUID/authz/resource-server/resource" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"$RESOURCE_NAME\",
    \"type\": \"topic\",
    \"ownerManagedAccess\": false,
    \"uris\": [\"$RESOURCE_NAME\"]
  }")

RESOURCE_ID=$(echo "$RESOURCE_RESPONSE" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')

if [ -z "$RESOURCE_ID" ]; then
  echo "ERROR: Could not create resource"
  exit 1
fi
