#!/bin/bash
set -e

KEYCLOAK_URL=${KEYCLOAK_URL:-"http://keycloak.keycloak.svc.cluster.local:8080"}
ADMIN_USER=${ADMIN_USER:-"admin-dk"}
ADMIN_PASS=${ADMIN_PASS:-"Secret123!"}
REALM="master"
CONFIG_FILE="/tmp/kcadm.config"

echo " Trying kcadm login..."
if ! /opt/keycloak/bin/kcadm.sh config credentials \
      --server "$KEYCLOAK_URL" \
      --realm "$REALM" \
      --user "$ADMIN_USER" \
      --password "$ADMIN_PASS" \
      --config "$CONFIG_FILE"; then
    
    echo " invalid_grant or login failure detected"
    echo " Fixing Keycloak admin user..."

    echo "→ Searching for user…"
    # Get raw user list; may return empty or JSON
    USER_RAW=$(/opt/keycloak/bin/kcadm.sh get users \
        -r "$REALM" \
        -q username="$ADMIN_USER" 2>/dev/null || true)

    # Very primitive parse: check if string contains "id"
    if echo "$USER_RAW" | grep -q '"id"'; then
        echo "→ User exists"
        # extract id without jq
        USER_ID=$(echo "$USER_RAW" | grep '"id"' | head -1 | sed 's/.*"id" : "\(.*\)".*/\1/')
    else
        echo "→ User missing — creating"
        /opt/keycloak/bin/kcadm.sh create users -r "$REALM" \
           -s username="$ADMIN_USER" \
           -s enabled=true

        # re-fetch user
        USER_RAW=$(/opt/keycloak/bin/kcadm.sh get users -r "$REALM" -q username="$ADMIN_USER")
        USER_ID=$(echo "$USER_RAW" | grep '"id"' | head -1 | sed 's/.*"id" : "\(.*\)".*/\1/')
    fi

    echo "→ Clearing requiredActions"
    /opt/keycloak/bin/kcadm.sh update users/$USER_ID -r "$REALM" \
       -s 'requiredActions=[]'

    echo "→ Resetting password"
/opt/keycloak/bin/kcadm.sh set-password \
       -r "$REALM" \
       --username "$ADMIN_USER" \
       --new-password "$ADMIN_PASS"

    echo "✔ Admin user fixed"
fi

echo " Logging in again…"
/opt/keycloak/bin/kcadm.sh config credentials \
      --server "$KEYCLOAK_URL" \
      --realm "$REALM" \
      --user "$ADMIN_USER" \
      --password "$ADMIN_PASS" \
      --config "$CONFIG_FILE"

echo "✔ kcadm logged in successfully"