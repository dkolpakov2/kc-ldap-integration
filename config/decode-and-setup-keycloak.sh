#!/bin/bash
#
# decode-and-setup-keycloak.sh
# Description: Reads base64-encoded Vault secret, decodes it,
# injects into ldap-config.json, and runs kcadm create components.
#
# chmod +x decode-and-setup-keycloak.sh
# ./decode-and-setup-keycloak.sh

#✅ What happens
# 1. Reads /vault/secrets/ldap → finds the base64 value.
# 2. Decodes it with base64 --decode.
# 3. Replaces ${vault.ldapCredential} in ldap-config.json.
# 4. Runs $KCADM create components ... safely.

set -euo pipefail

# --------------------------------------------
# Configuration
# --------------------------------------------
REALM="myrealm"
LDAP_CONFIG_FILE="/tmp/ldap-config.json"
VAULT_SECRET_FILE="/vault/secrets/ldap"
KCADM="/opt/keycloak/bin/kcadm.sh --config /tmp/kcadm.config"

# --------------------------------------------
# Step 1: Validate that the Vault secret file exists
# --------------------------------------------
if [ ! -f "$VAULT_SECRET_FILE" ]; then
  echo "[ERROR] Vault secret file not found: $VAULT_SECRET_FILE"
  exit 1
fi

# --------------------------------------------
# Step 2: Extract the base64-encoded credential
# --------------------------------------------
# Extract content between "bindCredential": ["..."]
LDAP_CRED_BASE64=$(grep -oP '(?<="bindCredential": \[")[^"]+' "$VAULT_SECRET_FILE")

if [ -z "$LDAP_CRED_BASE64" ]; then
  echo "[ERROR] Failed to extract bindCredential from $VAULT_SECRET_FILE"
  exit 1
fi

echo "[INFO] Base64-encoded credential read from Vault secret."

# --------------------------------------------
# Step 3: Decode the credential
# --------------------------------------------
LDAP_CRED=$(echo "$LDAP_CRED_BASE64" | base64 --decode)

if [ -z "$LDAP_CRED" ]; then
  echo "[ERROR] Decoded credential is empty!"
  exit 1
fi

echo "[INFO] Credential successfully decoded."

# --------------------------------------------
# Step 4: Inject into ldap-config.json
# --------------------------------------------
if [ ! -f "$LDAP_CONFIG_FILE" ]; then
  echo "[ERROR] LDAP config file not found: $LDAP_CONFIG_FILE"
  exit 1
fi

# Replace placeholder in JSON
sed -i "s|\${vault\.ldapCredential}|$LDAP_CRED|g" "$LDAP_CONFIG_FILE"

echo "[INFO] LDAP credential injected into $LDAP_CONFIG_FILE"

# --------------------------------------------
# Step 5: Create LDAP provider component in Keycloak
# --------------------------------------------
$KCADM create components -r "$REALM" -f "$LDAP_CONFIG_FILE"

if [ $? -eq 0 ]; then
  echo "[SUCCESS] LDAP provider successfully created in realm $REALM"
else
  echo "[ERROR] Failed to create LDAP provider in Keycloak."
  exit 1
fi
