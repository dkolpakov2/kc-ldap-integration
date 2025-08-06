#!/bin/bash

# Set Keycloak admin credentials and host info
KEYCLOAK_URL="http://localhost:8080"
KEYCLOAK_REALM="master"
KEYCLOAK_USER="admin"
KEYCLOAK_PASS="admin"

# Path to your JSON config (must be in importable format)
LDAP_CONFIG_FILE="ldap-config.json"

# Path to kcadm.sh - adjust if needed
KCADM="./bin/kcadm.sh"

# Login to Keycloak
$KCADM config credentials --server "$KEYCLOAK_URL" \
  --realm "$KEYCLOAK_REALM" \
  --user "$KEYCLOAK_USER" \
  --password "$KEYCLOAK_PASS"

# Import the LDAP component JSON into the master realm
$KCADM create components -r "$KEYCLOAK_REALM" -f "$LDAP_CONFIG_FILE"
