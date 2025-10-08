#!/bin/bash
# ============================================================
# Assigns the "admin" role to all users in a given Keycloak group
# ============================================================

# --- CONFIG ---
KC_REALM="kafka-usb-dev"
GROUP_NAME="ldap-admin-group"
KC_BASE_URL="http://localhost:8080"
KC_USER="admin"
KC_PASS="admin"
KC_CLIENT="admin-cli"
TMP_DIR="/tmp/kc_work"
mkdir -p "$TMP_DIR"

# --- LOGIN ---
echo "[INFO] Logging in..."
/opt/keycloak/bin/kcadm.sh config credentials --server "$KC_BASE_URL" --realm master --user "$KC_USER" --password "$KC_PASS" >/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "[ERROR] Failed to login to Keycloak"
  exit 1
fi

# --- GET GROUP ID ---
echo "[INFO] Fetching group ID for '$GROUP_NAME'..."
/opt/keycloak/bin/kcadm.sh get groups -r "$KC_REALM" > "$TMP_DIR/groups.json"
GROUP_ID=$(grep -B1 "\"name\"[[:space:]]*:[[:space:]]*\"$GROUP_NAME\"" "$TMP_DIR/groups.json" | grep '"id"' | sed 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

if [ -z "$GROUP_ID" ]; then
  echo "[ERROR] Group '$GROUP_NAME' not found in realm '$KC_REALM'"
  exit 1
fi
echo "[OK] Found group ID: $GROUP_ID"

# --- GET ADMIN ROLE ID ---
echo "[INFO] Fetching admin role ID..."
/opt/keycloak/bin/kcadm.sh get roles -r "$KC_REALM" > "$TMP_DIR/roles.json"
ADMIN_ROLE_ID=$(grep -B3 '"name" *: *"admin"' "$TMP_DIR/roles.json" | grep '"id"' | sed 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
if [ -z "$ADMIN_ROLE_ID" ]; then
  echo "[ERROR] 'admin' role not found in realm '$KC_REALM'"
  exit 1
fi
echo "[OK] Found admin role ID: $ADMIN_ROLE_ID"

# --- GET USERS IN GROUP ---
echo "[INFO] Fetching users from group '$GROUP_NAME'..."
/opt/keycloak/bin/kcadm.sh get "groups/$GROUP_ID/members" -r "$KC_REALM" > "$TMP_DIR/users.json"

USER_IDS=$(grep '"id"' "$TMP_DIR/users.json" | sed 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

if [ -z "$USER_IDS" ]; then
  echo "[WARN] No users found in group '$GROUP_NAME'"
  exit 0
fi

# --- ADD ROLE TO EACH USER ---
echo "[INFO] Assigning admin role to users..."
for USER_ID in $USER_IDS; do
  echo "  → Adding admin role to user $USER_ID..."
  /opt/keycloak/bin/kcadm.sh create "users/$USER_ID/role-mappings/realm" -r "$KC_REALM" \
    -f <(echo "[{\"id\":\"$ADMIN_ROLE_ID\",\"name\":\"admin\"}]") >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "    [OK] Done"
  else
    echo "    [ERROR] Failed to assign role to $USER_ID"
  fi
done

echo "[SUCCESS] Completed assigning 'admin' role to all users in group '$GROUP_NAME'."
