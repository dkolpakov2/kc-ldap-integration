#!/bin/bash
set -e

# Variables
KEYCLOAK_URL="http://localhost:8080"
ADMIN_USER="admin"
ADMIN_PASS="admin"
REALM_TO_DELETE="kafka-ubs-dev"

# Login to Keycloak Admin CLI
/opt/keycloak/bin/kcadm.sh config credentials \
  --server $KEYCLOAK_URL \
  --realm master \
  --user $ADMIN_USER \
  --password $ADMIN_PASS

# Delete realm
echo "Deleting realm: $REALM_TO_DELETE ..."
/opt/keycloak/bin/kcadm.sh delete realms/$REALM_TO_DELETE

echo "Realm '$REALM_TO_DELETE' deleted successfully."
