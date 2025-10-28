#!/bin/bash
set -e

# ==============================
# Usage:
#   ./restore-realm-entities.sh <REALM_NAME> <BACKUP_DIR>
#
# Example:
#   ./restore-realm-entities.sh myrealm /tmp/keycloak-backup
# ==============================

REALM_NAME=$1
BACKUP_DIR=$2

# --- Keycloak Admin CLI ---
KCADM="/opt/keycloak/bin/kcadm.sh"
KCADM_CONFIG="/tmp/kcadm.config"

# --- Connection info ---
KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8080}"
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASS="${ADMIN_PASS:-admin}"
MASTER_REALM="${MASTER_REALM:-master}"

# ==============================
# Validate input
# ==============================
if [[ -z "$REALM_NAME" || -z "$BACKUP_DIR" ]]; then
  echo "Usage: $0 <REALM_NAME> <BACKUP_DIR>"
  echo "Example: $0 myrealm /tmp/keycloak-backup"
  exit 1
fi

if [[ ! -d "$BACKUP_DIR" ]]; then
  echo "❌ Backup directory not found: $BACKUP_DIR"
  exit 1
fi

# ==============================
# Login to Keycloak
# ==============================
echo "🔐 Logging in to Keycloak..."
$KCADM config credentials \
  --config "$KCADM_CONFIG" \
  --server "$KEYCLOAK_URL" \
  --realm "$MASTER_REALM" \
  --user "$ADMIN_USER" \
  --password "$ADMIN_PASS"

# ==============================
# Restore Clients
# ==============================
CLIENTS_FILE="$BACKUP_DIR/clients.json"
if [[ -f "$CLIENTS_FILE" ]]; then
  echo "📦 Restoring clients from $CLIENTS_FILE"
  while IFS= read -r line; do
    # Skip empty lines or comments
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    echo "$line" > /tmp/client.json
    $KCADM create clients -r "$REALM_NAME" -f /tmp/client.json \
      --config "$KCADM_CONFIG" || echo "⚠️ Failed to import client entry"
  done < <(grep -o '{[^}]*}' "$CLIENTS_FILE")
else
  echo "ℹ️ No clients.json found, skipping clients restore."
fi

# ==============================
# Restore Groups
# ==============================
GROUPS_FILE="$BACKUP_DIR/groups.json"
if [[ -f "$GROUPS_FILE" ]]; then
  echo "📦 Restoring groups from $GROUPS_FILE"
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    echo "$line" > /tmp/group.json
    $KCADM create groups -r "$REALM_NAME" -f /tmp/group.json \
      --config "$KCADM_CONFIG" || echo "⚠️ Failed to import group entry"
  done < <(grep -o '{[^}]*}' "$GROUPS_FILE")
else
  echo "ℹ️ No groups.json found, skipping groups restore."
fi

# ==============================
# Restore Users
# ==============================
USERS_FILE="$BACKUP_DIR/users.json"
if [[ -f "$USERS_FILE" ]]; then
  echo "📦 Restoring users from $USERS_FILE"
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    echo "$line" > /tmp/user.json
    $KCADM create users -r "$REALM_NAME" -f /tmp/user.json \
      --config "$KCADM_CONFIG" || echo "⚠️ Failed to import user entry"
  done < <(grep -o '{[^}]*}' "$USERS_FILE")
else
  echo "ℹ️ No users.json found, skipping users restore."
fi

# ==============================
# Completion
# ==============================
echo "✅ Restore completed for realm '$REALM_NAME'"
echo "Clients, Groups, and Users imported from: $BACKUP_DIR"
