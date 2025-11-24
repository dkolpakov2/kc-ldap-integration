#!/usr/bin/env bash

REALM="kafka-dry-run"
ADMIN_USER="$1"
ADMIN_PASS="$2"
CONFIG="/tmp/kcadm.config"
## USe
# chmod +x add-hashicorp-user-provider.sh
# ./add-hashicorp-user-provider.sh admin-user admin-password
# Modify these values according to your SPI:
# providerId="hashicorp-user-provider"
# providerType="org.keycloak.storage.UserStorageProvider"
# vault settings:
# vaultAddress
# vaultToken
# secretPath

# --- login ---
/opt/keycloak/bin/kcadm.sh config credentials \
  --config "$CONFIG" \
  --server http://localhost:8080 \
  --realm master \
  --user "$ADMIN_USER" \
  --password "$ADMIN_PASS"

echo "Logged in."

# --- CREATE Federation Provider ---
echo "Creating Hashicorp user federation provider..."

/opt/keycloak/bin/kcadm.sh create components -r "$REALM" \
  --config "$CONFIG" \
  -s name="hashicorp-user-provider" \
  -s providerId="hashicorp-user-provider" \
  -s providerType="org.keycloak.storage.UserStorageProvider" \
  -s parentId="$REALM" \
  -s 'config.cachePolicy=["DEFAULT"]' \
  -s 'config.syncRegistrations=["false"]' \
  -s 'config.fullSyncPeriod=["-1"]' \
  -s 'config.changedSyncPeriod=["-1"]' \
  -s 'config.vaultAddress=["http://vault.default.svc.cluster.local:8200"]' \
  -s 'config.vaultToken=["${VAULT_TOKEN}"]' \
  -s 'config.secretPath=["secret/data/keycloak-users"]'

echo "Hashicorp User Federation Provider added to realm '$REALM'."
