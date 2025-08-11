#!/bin/bash
set -e

# Wait for Keycloak to be up before calling the API
echo " Waiting for Keycloak to start..."
until curl -sf http://localhost:8080/health/ready > /dev/null; do
  sleep 2
done
echo " Keycloak is up."

# Variables (update if needed)
KEYCLOAK_URL="http://localhost:8080"
REALM="myrealm"
ADMIN_USER="admin"
ADMIN_PASS="admin"

echo " Getting admin access token..."
ACCESS_TOKEN=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASS}" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | jq -r .access_token)

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
  echo "Failed to get access token."
  exit 1
fi

echo "Finding LDAP provider ID..."
LDAP_PROVIDER_ID=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/components" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  | jq -r '.[] | select(.providerId=="ldap") | .id')

if [ -z "$LDAP_PROVIDER_ID" ]; then
  echo "No LDAP provider found in realm ${REALM}."
  exit 1
fi

echo "Triggering LDAP group sync..."
SYNC_RESULT=$(curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/user-storage/${LDAP_PROVIDER_ID}/sync?action=triggerFullSync" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json")

echo "LDAP group sync triggered: ${SYNC_RESULT}"
