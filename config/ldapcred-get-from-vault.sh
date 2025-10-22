#!/bin/bash

# ===============================================
# Inputs
# ===============================================
REALM="myrealm"
LDAP_CONFIG_FILE="/tmp/ldap-config.json"
VAULT_SECRET_PATH="secret/data/ldap"
KCADM="/opt/keycloak/bin/kcadm.sh --config /tmp/kcadm.config"

# ===============================================
# Step 1: Read secret from HashiCorp Vault
# (Assuming vault CLI is already authenticated)
# ===============================================
echo "[INFO] Fetching LDAP credential from Vault..."
LDAP_CREDENTIAL=$(vault kv get -field=ldapCredential "$VAULT_SECRET_PATH")

if [ -z "$LDAP_CREDENTIAL" ]; then
  echo "[ERROR] Could not retrieve ldapCredential from Vault at: $VAULT_SECRET_PATH"
  exit 1
fi

# ===============================================
# Step 2: Inject secret into ldap-config.json
# ===============================================
echo "[INFO] Injecting credential into $LDAP_CONFIG_FILE"

# We'll create a temporary file to avoid partial write issues
TEMP_FILE="/tmp/ldap-config.tmp.json"

# Replace the placeholder ${vault.ldapCredential} with actual secret value
sed "s|\${vault\.ldapCredential}|$LDAP_CREDENTIAL|g" "$LDAP_CONFIG_FILE" > "$TEMP_FILE"

# Replace original file
mv "$TEMP_FILE" "$LDAP_CONFIG_FILE"

# ===============================================
# Step 3: Create LDAP component in Keycloak
# ===============================================
echo "[INFO] Creating LDAP provider in realm $REALM..."
$KCADM create components -r "$REALM" -f "$LDAP_CONFIG_FILE"

if [ $? -eq 0 ]; then
  echo "[SUCCESS] LDAP provider successfully created."
else
  echo "[ERROR] Failed to create LDAP provider."
  exit 1
fi
