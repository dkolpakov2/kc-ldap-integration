#!/bin/bash
set -euo pipefail

# === CONFIG ===
VAULT_PATH="secret/data/keycloak/admin"
K8S_SECRET_NAME="keycloak-admin-creds"
K8S_NAMESPACE="keycloak"
KEYCLOAK_DEPLOYMENT="keycloak"
KCADM="/opt/keycloak/bin/kcadm.sh"
CONFIG="/tmp/kcadm.config"
SERVER_URL="http://localhost:8080"
REALM="master"
ADMIN_USER="admin"

# === STEP 1: Generate new password and update Vault ===
NEW_PASS=$(openssl rand -base64 14)
echo "🔑 Rotating Keycloak admin password in Vault..."

vault kv put "${VAULT_PATH%/data/*}/data/keycloak/admin" password="$NEW_PASS" username="$ADMIN_USER"

# === STEP 2: Sync Vault secret to Kubernetes ===
echo "📦 Updating Kubernetes Secret..."
kubectl create secret generic "$K8S_SECRET_NAME" \
  --from-literal=KEYCLOAK_ADMIN="$ADMIN_USER" \
  --from-literal=KEYCLOAK_ADMIN_PASSWORD="$NEW_PASS" \
  -n "$K8S_NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

# === STEP 3: Restart Keycloak Pods ===
echo "♻️ Restarting Keycloak deployment..."
kubectl rollout restart deployment/"$KEYCLOAK_DEPLOYMENT" -n "$K8S_NAMESPACE"

# === STEP 4: Wait for Keycloak to come back online ===
echo "⏳ Waiting for Keycloak to be ready..."
kubectl rollout status deployment/"$KEYCLOAK_DEPLOYMENT" -n "$K8S_NAMESPACE"

# === STEP 5: (Optional) Update password in running Keycloak via kcadm ===
echo "🔐 Logging in with new credentials..."
$KCADM config credentials \
  --server "$SERVER_URL" \
  --realm "$REALM" \
  --user "$ADMIN_USER" \
  --password "$NEW_PASS" \
  --config "$CONFIG" || true

echo "✅ Rotation completed successfully."
