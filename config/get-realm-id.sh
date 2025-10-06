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

# option to use grep/sed
# Get raw JSON list of realms
REALMS_JSON=$(/opt/keycloak/bin/kcadm.sh get realms --fields id,realm)

# Extract the line with our realm
# Remove spaces and quotes for easier parsing
CLEANED=$(echo "$REALMS_JSON" | tr -d ' ' | tr -d '"' )

# Find matching realm block and extract id
# Example input: [{"id":"master","realm":"master"},{"id":"kafka-usb-dev","realm":"kafka-usb-dev"}]
REALM_ID=$(echo "$CLEANED" | sed -n "s/.*id:\([^,}]*\),realm:$REALM_NAME.*/\1/p")

if [ -z "$REALM_ID" ]; then
  echo "❌ Realm '$REALM_NAME' not found."
  exit 1
else
  echo "✅ Realm '$REALM_NAME' ID: $REALM_ID"
fi




# By USing JQ
# Fetch the realm list and extract the ID for the given name
REALM_ID=$(/opt/keycloak/bin/kcadm.sh get realms --fields id,realm | jq -r --arg realm "$REALM_NAME" '.[] | select(.realm==$realm) | .id')

if [ -z "$REALM_ID" ]; then
  echo "❌ Realm '$REALM_NAME' not found."
  exit 1
else
  echo "✅ Realm '$REALM_NAME' ID: $REALM_ID"
fi
