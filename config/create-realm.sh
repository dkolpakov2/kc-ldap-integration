#!/bin/bash
set -e

# Variables
KEYCLOAK_URL="http://localhost:8080"
REALM="kafka-ubs-dev"
ADMIN_USER="admin"
ADMIN_PASS="admin"

# Login to Keycloak
/opt/keycloak/bin/kcadm.sh config credentials \
  --server $KEYCLOAK_URL \
  --realm master \
  --user $ADMIN_USER \
  --password $ADMIN_PASS

# Check if realm already exists
if /opt/keycloak/bin/kcadm.sh get realms/$REALM >/dev/null 2>&1; then
  echo "Realm '$REALM' already exists. Skipping creation."
else
  echo "Creating realm: $REALM"
  /opt/keycloak/bin/kcadm.sh create realms -s realm=$REALM -s enabled=true
  echo " Realm '$REALM' created successfully."
fi