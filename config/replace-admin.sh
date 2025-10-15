#!/bin/bash
set -e
# RUN:
# kubectl cp replace-admin.sh dev/keycloak-0:/tmp/replace-admin.sh
# RUN inside pod:
# kubectl exec -it keycloak-0 -n dev -- bash /tmp/replace-admin.sh
# kubectl exec -it keycloak-0 -n dev -- bash /tmp/replace-admin.sh

# --- Configuration ---
REALM="master"
NEW_ADMIN_USER="adminuser"
NEW_ADMIN_PASS="StrongPassword123!"
TEMP_ADMIN_USER="keycloak"
TEMP_ADMIN_PASS="${KEYCLOAK_ADMIN_PASSWORD:-admin}"
KEYCLOAK_URL="http://localhost:8080"   # adjust if running remotely

echo "=== Step 1: Log in with temporary admin user ==="
$KEYCLOAK_HOME/bin/kcadm.sh config credentials \
  --server $KEYCLOAK_URL/auth \
  --realm $REALM \
  --user $TEMP_ADMIN_USER \
  --password $TEMP_ADMIN_PASS

echo "=== Step 2: Create new admin user ==="
# Check if the new admin already exists
USER_ID=$($KEYCLOAK_HOME/bin/kcadm.sh get users -r $REALM --query username=$NEW_ADMIN_USER --fields id --format csv | tail -n +2)

if [ -z "$USER_ID" ]; then
  $KEYCLOAK_HOME/bin/kcadm.sh create users -r $REALM \
    -s username=$NEW_ADMIN_USER \
    -s enabled=true
  echo "New admin user '$NEW_ADMIN_USER' created."
else
  echo "Admin user '$NEW_ADMIN_USER' already exists."
fi

# Set password
echo "=== Step 3: Set password for new admin user ==="
$KEYCLOAK_HOME/bin/kcadm.sh set-password -r $REALM \
  --username $NEW_ADMIN_USER \
  --new-password $NEW_ADMIN_PASS

# Assign admin role
echo "=== Step 4: Assign realm-admin role ==="
$KEYCLOAK_HOME/bin/kcadm.sh add-roles -r $REALM \
  --uusername $NEW_ADMIN_USER \
  --rolename realm-admin \
  --cclientid realm-management

echo "=== Step 5: Verify new admin can log in ==="
$KEYCLOAK_HOME/bin/kcadm.sh config credentials \
  --server $KEYCLOAK_URL/auth \
  --realm $REALM \
  --user $NEW_ADMIN_USER \
  --password $NEW_ADMIN_PASS

echo "=== Step 6: Remove temporary admin user ==="
TEMP_ID=$($KEYCLOAK_HOME/bin/kcadm.sh get users -r $REALM --query username=$TEMP_ADMIN_USER --fields id --format csv | tail -n +2)
if [ -n "$TEMP_ID" ]; then
  $KEYCLOAK_HOME/bin/kcadm.sh delete users/$TEMP_ID -r $REALM
  echo "Temporary admin user '$TEMP_ADMIN_USER' removed."
else
  echo "Temporary admin '$TEMP_ADMIN_USER' not found."
fi

echo "✅ Admin user replacement complete!"