#!/bin/bash
set -e

# Input realm name
REALM_NAME="kafka-usb-dev"

# Login to Keycloak (update values as needed)
export KC_ADMIN_USER="admin"
export KC_ADMIN_PASS="admin_password"
export KC_HOST="http://localhost:8080"
export KC_REALM="master"

# Login to Keycloak
/opt/keycloak/bin/kcadm.sh config credentials --server "$KC_HOST" --realm "$KC_REALM" --user "$KC_ADMIN_USER" --password "$KC_ADMIN_PASS"

# Fetch the realm list and extract the ID for the given name
REALM_ID=$(/opt/keycloak/bin/kcadm.sh get realms --fields id,realm | jq -r --arg realm "$REALM_NAME" '.[] | select(.realm==$realm) | .id')

if [ -z "$REALM_ID" ]; then
  echo "❌ Realm '$REALM_NAME' not found."
  exit 1
else
  echo "✅ Realm '$REALM_NAME' ID: $REALM_ID"
fi
