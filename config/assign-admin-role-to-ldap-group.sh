#!/bin/bash
set -e

# Variables
KEYCLOAK_URL="http://localhost:8080"
REALM="kafka-ubs-dev"
ADMIN_USER="admin"
ADMIN_PASS="admin"
LDAP_GROUP_NAME="ldap-admins"   # the LDAP group name as it appears in Keycloak

# Login to Keycloak Admin CLI
/opt/keycloak/bin/kcadm.sh config credentials \
  --server $KEYCLOAK_URL \
  --realm master \
  --user $ADMIN_USER \
  --password $ADMIN_PASS

# Get LDAP group ID inside the realm
GROUP_ID=$(/opt/keycloak/bin/kcadm.sh get groups -r $REALM --fields id,name \
  --format csv | grep ",$LDAP_GROUP_NAME" | cut -d',' -f1)

if [[ -z "$GROUP_ID" ]]; then
  echo " Group '$LDAP_GROUP_NAME' not found in realm '$REALM'."
  exit 1
fi

echo " Found group '$LDAP_GROUP_NAME' with ID: $GROUP_ID"
# Run manual for testing
/opt/keycloak/bin/kcadm.sh get clients -r $REALM --fields id,clientId | grep realm-management
## If no result, it means realm-management doesn’t exist in that realm (it may only be in master).


# Get the "admin" realm role (from master realm’s "realm-management" client)
CLIENT_ID=$(/opt/keycloak/bin/kcadm.sh get clients -r $REALM \
  -q clientId=realm-management --fields id --format csv | tail -n +2)
# Ged data with JSON format
CLIENT_ID=$(/opt/keycloak/bin/kcadm.sh get clients -r $REALM --query clientId=realm-management --fields id | sed -n 's/.*"id" : "\(.*\)".*/\1/p')

ROLE_JSON=$(/opt/keycloak/bin/kcadm.sh get clients/$CLIENT_ID/roles/admin -r $REALM)

# Assign the "admin" role to the LDAP group
echo "$ROLE_JSON" | /opt/keycloak/bin/kcadm.sh create groups/$GROUP_ID/role-mappings/clients/$CLIENT_ID \
  -r $REALM -f -+
echo "Group '$LDAP_GROUP_NAME' assigned Keycloak admin role successfully."
