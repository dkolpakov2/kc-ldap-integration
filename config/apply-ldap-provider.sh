#!/bin/bash

# Set Keycloak admin credentials and host info
KEYCLOAK_URL="http://localhost:8080"
KEYCLOAK_REALM="master"
KEYCLOAK_USER="admin"
KEYCLOAK_PASS="admin"

# Path to your JSON config (must be in importable format)
LDAP_CONFIG_FILE="ldap-config.json"
 Define the container name
CONTAINER_NAME="keycloak"

# Get the running container ID (partial name match)
CONTAINER_ID=$(docker ps -qf "name=$CONTAINER_NAME")

# Check if container was found
if [ -z "$CONTAINER_ID" ]; then
  echo "Container with name '$CONTAINER_NAME' not found or not running."
  exit 111
fi

echo "Found container: $CONTAINER_ID"
# Example: Run a command inside the container
docker exec "$CONTAINER_ID" sh ./opt/keycloak/bin/kcadm.sh

# Path to kcadm.sh - adjust if needed
KCADM="./opt/keycloak/kcadm.sh"

# Login to Keycloak
$KCADM config credentials --server "$KEYCLOAK_URL" \
  --realm "$KEYCLOAK_REALM" \
  --user "$KEYCLOAK_USER" \
  --password "$KEYCLOAK_PASS"

# Import the LDAP component JSON into the master realm
$KCADM create components -r "$KEYCLOAK_REALM" -f "$LDAP_CONFIG_FILE"
