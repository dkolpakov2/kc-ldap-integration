#!/bin/bash
set -e

# ==============================
# Usage:
#   ./restore-realm.sh <REALM_NAME> <REALM_JSON_FILE>
#
# Example:
#   ./restore-realm.sh myrealm /backup/myrealm-realm.json
# ==============================

## Azure Blob Storage Integration
# If your backup JSON is stored in Azure Blob, you can download before restore:
# az storage blob download --account-name <account> --container-name <container> --name <realm-file>.json --file /tmp/realm.json
# ./restore-realm.sh myrealm /tmp/realm.json


REALM_NAME=$1
REALM_FILE=$2

KCADM="/opt/keycloak/bin/kcadm.sh"
KCADM_CONFIG="/tmp/kcadm.config"
KEYCLOAK_URL="http://localhost:8080"
ADMIN_USER="admin" # 
ADMIN_PASS="admin" # ADMIN_PASS=$(vault kv get -field=admin_pass secret/keycloak/admin)
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASS="${ADMIN_PASS:-admin}"
KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8080}"

REALM_MASTER="master"

# ==============================
# Validate input
# ==============================
if [[ -z "$REALM_NAME" || -z "$REALM_FILE" ]]; then
  echo "Usage: $0 <REALM_NAME> <REALM_JSON_FILE>"
  exit 1
fi

if [[ ! -f "$REALM_FILE" ]]; then
  echo " File not found: $REALM_FILE"
  exit 1
fi

# ==============================
# Login to Keycloak
# ==============================
echo " Logging in to Keycloak..."
$KCADM config credentials --config "$KCADM_CONFIG" --server "$KEYCLOAK_URL" --realm "$REALM_MASTER" --user "$ADMIN_USER" --password "$ADMIN_PASS"

# ==============================
# Check if realm exists
# ==============================
EXISTS=$($KCADM get realms/"$REALM_NAME" --config "$KCADM_CONFIG" --server "$KEYCLOAK_URL" --realm "$REALM_MASTER" --fields realm --format csv 2>/dev/null || true)

if [[ -n "$EXISTS" ]]; then
  echo " Realm '$REALM_NAME' already exists. Deleting existing realm before restore..."
  $KCADM delete realms/"$REALM_NAME" --config "$KCADM_CONFIG" --server "$KEYCLOAK_URL" --realm "$REALM_MASTER"
fi

# ==============================
# Import realm from JSON file
# ==============================
echo " Importing realm from: $REALM_FILE"
$KCADM create realms -f "$REALM_FILE" --config "$KCADM_CONFIG" --server "$KEYCLOAK_URL" --realm "$REALM_MASTER"

echo " Realm '$REALM_NAME' successfully restored from $REALM_FILE"
