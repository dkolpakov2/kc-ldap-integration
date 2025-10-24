#!/bin/bash
set -euo pipefail

# === USAGE ===
# ./backup-realm-to-azure.sh <realm-name>

# |Step| Description                                                     |
# |--- | --------------------------------------------------------------- |
# | 1️  | Export full Keycloak realm JSON using `kcadm.sh`                |
# | 2️  | Store file locally in `/tmp/keycloak-backups`                   |
# | 3️  | Upload to **Azure Blob Storage** using `az storage blob upload` |
# | 4️  | (Optional) Run via CronJob to automate daily backups            |


REALM_NAME="$1"
if [ -z "$REALM_NAME" ]; then
  echo " Usage: $0 <realm-name>"
  exit 1
fi

# === CONFIG ===
KCADM="/opt/keycloak/bin/kcadm.sh"
CONFIG_FILE="/tmp/kcadm.config"
SERVER_URL="http://localhost:8080"
BACKUP_DIR="/tmp/keycloak-backups"
STORAGE_ACCOUNT="mykeycloakstorage"
CONTAINER_NAME="keycloak-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTPUT_FILE="${BACKUP_DIR}/${REALM_NAME}-${TIMESTAMP}.json"

mkdir -p "$BACKUP_DIR"

# === CHECK LOGIN ===
if ! $KCADM get realms --config "$CONFIG_FILE" >/dev/null 2>&1; then
  echo " Not logged in to Keycloak admin CLI. Please authenticate first."
  exit 1
fi

# === EXPORT REALM ===
echo " Exporting realm '$REALM_NAME'..."
$KCADM get realms/"$REALM_NAME" --config "$CONFIG_FILE" > "$OUTPUT_FILE"

if [ ! -s "$OUTPUT_FILE" ]; then
  echo " Export failed, no data saved."
  exit 1
fi

# === UPLOAD TO AZURE ===
echo " Uploading backup to Azure Blob Storage..."
az storage blob upload \
  --account-name "$STORAGE_ACCOUNT" \
  --container-name "$CONTAINER_NAME" \
  --file "$OUTPUT_FILE" \
  --name "$(basename "$OUTPUT_FILE")" \
  --auth-mode login

echo " Realm backup successfully uploaded to Azure!"
echo " File: $OUTPUT_FILE"

## =======================================================
## Optional — Use a SAS Token Instead of az login

az storage account generate-sas \
  --account-name mykeycloakstorage \
  --permissions acdlrw \
  --resource-types sco \
  --services b \
  --expiry 2025-12-31T23:59:00Z

#USage
export AZURE_STORAGE_SAS_TOKEN="?sv=2025-..."
export AZURE_STORAGE_ACCOUNT="mykeycloakstorage"

## Now we can upload using:
az storage blob upload \
  --container-name keycloak-backups \
  --file "$OUTPUT_FILE" \
  --name "$(basename "$OUTPUT_FILE")"
