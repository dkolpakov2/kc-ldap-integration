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
ROLE_NAME=$ROLE_NAME
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

# --- GET GROUP ID ---
echo "[INFO] Getting group ID for '$GROUP_NAME'..."
GROUPS_JSON=$(/opt/keycloak/bin/kcadm.sh get groups -r "$KC_REALM")
GROUP_ID=$(printf '%s\n' "$GROUPS_JSON" | grep -B1 "\"name\" *: *\"$GROUP_NAME\"" | grep '"id"' | sed 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

if [ -z "$GROUP_ID" ]; then
  echo "[ERROR] Group '$GROUP_NAME' not found in realm '$KC_REALM'."
  exit 1
fi
echo "[OK] Found group ID: $GROUP_ID"

# --- CHECK IF REALM EXISTS ---
echo "[INFO] Checking realm '$REALM'..."
REALMS_JSON=$(/opt/keycloak/bin/kcadm.sh get realms)
REALM_EXISTS=$(printf '%s\n' "$REALMS_JSON" | grep "\"realm\" *: *\"$REALM\"" || true)

if [ -z "$REALM_EXISTS" ]; then
  echo "[ERROR] Realm '$REALM' does not exist. Please create it first."
  exit 1
fi
echo "[OK] Realm '$REALM' exists."


# --- CHECK IF ADMIN ROLE ALREADY EXISTS ---
echo "[INFO] Checking if role '$ROLE_NAME' already exists..."
ROLES_JSON=$(/opt/keycloak/bin/kcadm.sh get roles -r "$REALM")
ROLE_EXISTS=$(printf '%s\n' "$ROLES_JSON" | grep "\"name\" *: *\"$ROLE_NAME\"" || true)

if [ -n "$ROLE_EXISTS" ]; then
  echo "[WARN] Role '$ROLE_NAME' already exists in realm '$REALM'. Skipping creation."
  exit 0
fi

# --- CREATE ADMIN ROLE ---
echo "[INFO] Creating realm role '$ROLE_NAME'..."
CREATE_RESULT=$(/opt/keycloak/bin/kcadm.sh create roles -r "$REALM" \
  -s name="$ROLE_NAME" \
  -s description="Administrator role for realm $REALM" 2>&1)

if echo "$CREATE_RESULT" | grep -qi "Created"; then
  echo "[SUCCESS] Role '$ROLE_NAME' created successfully in realm '$REALM'."
else
  echo "[ERROR] Failed to create role. Output:"
  echo "$CREATE_RESULT"
  exit 1
fi

# --- GET ADMIN ROLE ID ---
echo "[INFO] Getting 'admin' role ID..."
ROLES_JSON=$(/opt/keycloak/bin/kcadm.sh get roles -r "$KC_REALM")
ADMIN_ROLE_ID=$(printf '%s\n' "$ROLES_JSON" | grep -B3 '"name" *: *"admin"' | grep '"id"' | sed 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

if [ -z "$ADMIN_ROLE_ID" ]; then
  echo "[ERROR] Role 'admin' not found in realm '$KC_REALM'."
  exit 1
fi
echo "[OK] Found admin role ID: $ADMIN_ROLE_ID"

# --- GET USERS IN GROUP ---
echo "[INFO] Getting users in group '$GROUP_NAME'..."
USERS_JSON=$(/opt/keycloak/bin/kcadm.sh get "groups/$GROUP_ID/members" -r "$KC_REALM")
USER_IDS=$(printf '%s\n' "$USERS_JSON" | grep '"id"' | sed 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

if [ -z "$USER_IDS" ]; then
  echo "[WARN] No users found in group '$GROUP_NAME'."
  exit 0
fi

# --- ASSIGN ADMIN ROLE TO EACH USER ---
echo "[INFO] Assigning 'admin' role to all users..."
for USER_ID in $USER_IDS; do
  echo "  → Adding role to user: $USER_ID"
  /opt/keycloak/bin/kcadm.sh create "users/$USER_ID/role-mappings/realm" -r "$KC_REALM" \
    -f <(printf '[{"id":"%s","name":"admin"}]' "$ADMIN_ROLE_ID") >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "    [OK] Done"
  else
    echo "    [ERROR] Failed for user $USER_ID"
  fi
done

echo "[SUCCESS] Admin role assigned to all users in group '$GROUP_NAME'."