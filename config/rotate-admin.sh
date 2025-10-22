#!/bin/bash
set -e
# Usage:
# ./rotate-admin.sh NewStrongPassword123!

KCADM="/opt/keycloak/bin/kcadm.sh"
CONFIG="/tmp/kcadm.config"
SERVER_URL="http://localhost:8080"
REALM="master"
ADMIN_USER="admin"
NEW_PASS="$1"

if [ -z "$NEW_PASS" ]; then
  echo "Usage: $0 <new_password>"
  exit 1
fi

echo "🔑 Rotating admin password..."
USER_ID=$($KCADM get users -r $REALM -q username=$ADMIN_USER --config $CONFIG | grep -o '"id" : "[^"]*' | cut -d'"' -f4)

$KCADM update users/$USER_ID -r $REALM \
  -s "credentials=[{'type':'password','value':'$NEW_PASS','temporary':false}]" \
  --config $CONFIG

echo "✅ Password rotated successfully."

echo "🔐 Fetching new token..."
TOKEN=$(curl -s -X POST "$SERVER_URL/realms/$REALM/protocol/openid-connect/token" \
  -d "client_id=admin-cli" \
  -d "username=$ADMIN_USER" \
  -d "password=$NEW_PASS" \
  -d "grant_type=password" | grep -oP '(?<=\"access_token\":\")[^\"]+')

echo "🔄 Reconfiguring kcadm to use token..."
$KCADM config credentials --server $SERVER_URL --realm $REALM --client admin-cli --token "$TOKEN"

echo "✅ New token configured. You’re ready to run secure commands."
