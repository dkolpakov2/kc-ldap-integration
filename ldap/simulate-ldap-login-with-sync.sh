#!/bin/bash

# --- CONFIGURATION ---
KC_HOST="http://localhost:8080"             # local test Or DEV AKS Keycloak endpoint
REALM="master"
CLIENT_ID="test-client"
USERNAME="ldap-user"
PASSWORD="ldap-password"

# Admin credentials (must be realm admin or Keycloak admin)
ADMIN_USER="admin"  
ADMIN_PASS="admin"  # or password

# LDAP User Federation ID (can be found in the Admin UI or via API)
PROVIDER_ID="ldap"       # Usually "ldap", needs to be changed if different

# --- 1. Authenticate as Admin ---
echo "receiving admin token..."
ADMIN_TOKEN=$(curl -s -X POST "$KC_HOST/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=$ADMIN_USER" \
  -d "password=$ADMIN_PASS" | jq -r .access_token)

if [[ "$ADMIN_TOKEN" == "null" || -z "$ADMIN_TOKEN" ]]; then
  echo " Failed to get admin token"
  exit 1
fi

# --- 2. Sync LDAP Users ---
echo "Syncing LDAP users..."
SYNC_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "$KC_HOST/admin/realms/$REALM/user-storage/$PROVIDER_ID/sync" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

if [[ "$SYNC_STATUS" != "204" ]]; then
  echo "LDAP sync failed: $SYNC_STATUS"
  exit 1
else
  echo "LDAP sync triggered successfully."
fi

# --- 3. Simulate Login ---
echo "Attempting login as LDAP user: $USERNAME"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$KC_HOST/realms/$REALM/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$CLIENT_ID" \
  -d "grant_type=password" \
  -d "username=$USERNAME" \
  -d "password=$PASSWORD")

BODY=$(echo "$RESPONSE" | head -n -1)
STATUS=$(echo "$RESPONSE" | tail -n1)

if [ "$STATUS" == "200" ]; then
  echo "LDAP login successful!"
  echo "$BODY" | jq '.access_token' | cut -c1-80
else
  echo "LDAP login failed. Status: $STATUS"
  echo "$BODY"
fi