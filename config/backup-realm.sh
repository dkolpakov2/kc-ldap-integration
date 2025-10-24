#!/bin/bash
set -euo pipefail

# === USAGE ===
# ./backup-realm.sh <realm-name>
# Example: ./backup-realm.sh myrealm
# Steps:
# 🔐 Checking Keycloak admin login...
# 📦 Exporting realm 'myrealm'...
# ✅ Backup completed successfully!
# 📁 File: /tmp/keycloak-backups/myrealm-20251013-152330.json
# 📏 Size: 42K



REALM_NAME="$1"
if [ -z "$REALM_NAME" ]; then
  echo "❌ Usage: $0 <realm-name>"
  exit 1
fi

# === CONFIGURATION ===
KCADM="/opt/keycloak/bin/kcadm.sh"
CONFIG_FILE="/tmp/kcadm.config"
SERVER_URL="http://localhost:8080"
BACKUP_DIR="/tmp/keycloak-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTPUT_FILE="${BACKUP_DIR}/${REALM_NAME}-${TIMESTAMP}.json"

mkdir -p "$BACKUP_DIR"

# === CHECK KCADM LOGIN ===
echo "🔐 Checking Keycloak admin login..."
if ! $KCADM get realms --config "$CONFIG_FILE" >/dev/null 2>&1; then
  echo "⚠️ Not logged in. Please login first:"
  echo "$KCADM config credentials --server $SERVER_URL --realm master --user admin --password <password> --config $CONFIG_FILE"
  exit 1
fi

# === EXPORT REALM ===
echo "📦 Exporting realm '$REALM_NAME'..."
$KCADM get realms/"$REALM_NAME" --config "$CONFIG_FILE" > "$OUTPUT_FILE"

# === VERIFY BACKUP ===
if [ ! -s "$OUTPUT_FILE" ]; then
  echo "❌ Backup failed — file is empty."
  exit 1
fi

# === STATS ===
REALM_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
echo "✅ Backup completed successfully!"
echo "📁 File: $OUTPUT_FILE"
echo "📏 Size: $REALM_SIZE"


## Optional 
## Optional: Include Users, Groups, and Clients Separately
$KCADM get users -r "$REALM_NAME" --config "$CONFIG_FILE" > "${BACKUP_DIR}/${REALM_NAME}-users-${TIMESTAMP}.json"
$KCADM get groups -r "$REALM_NAME" --config "$CONFIG_FILE" > "${BACKUP_DIR}/${REALM_NAME}-groups-${TIMESTAMP}.json"
$KCADM get clients -r "$REALM_NAME" --config "$CONFIG_FILE" > "${BACKUP_DIR}/${REALM_NAME}-clients-${TIMESTAMP}.json"

