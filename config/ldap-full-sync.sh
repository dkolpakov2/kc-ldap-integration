#!/bin/bash
(Triggers Keycloak’s Full Sync for a specific user federation provider)

set -euo pipefail

# ----------------------------
# CONFIGURATION
# ----------------------------
KEYCLOAK_URL="https://keycloak.example.com"
REALM="myrealm"
ADMIN_USER="admin"
ADMIN_PASSWORD="adminpassword"
CLIENT_ID="admin-cli"

KC_URL="$1"
REALM="$2"
PROVIDER_ID="$3"
ADMIN_USER="$4"
ADMIN_PASS="$5"

if [[ -z "$KC_URL" || -z "$REALM" || -z "$PROVIDER_ID" || -z "$ADMIN_USER" || -z "$ADMIN_PASS" ]]; then
  echo "❌ Usage: $0 <KEYCLOAK_URL> <REALM> <LDAP_PROVIDER_ID> <ADMIN_USER> <ADMIN_PASS>"
  echo "Example: $0 http://localhost:8080 master ldap-provider admin admin123"
  exit 1
fi

# Path to Keycloak kcadm.sh tool
KCADM="/opt/keycloak/bin/kcadm.sh"

# ----------------------------
# LOGIN
# ----------------------------
echo "🔐 Logging into Keycloak..."
$KCADM config credentials \
  --server "$KEYCLOAK_URL" \
  --realm master \
  --user "$ADMIN_USER" \
  --password "$ADMIN_PASSWORD" \
  --client "$CLIENT_ID"

echo "✅ Logged in successfully."

# ----------------------------
# GET LDAP USER STORAGE PROVIDER ID
# ----------------------------
echo " Fetching LDAP provider ID for realm: $REALM..."
PROVIDER_ID=$($KCADM get components \
  -r "$REALM" \
  --fields id,name,providerId \
  --format csv | grep ldap | head -1 | cut -d',' -f1)

if [[ -z "$PROVIDER_ID" ]]; then
  echo " LDAP provider not found in realm $REALM."
  exit 1
fi

echo "✅ Found LDAP provider ID: $PROVIDER_ID"

# ----------------------------
# RUN FULL SYNC
# ----------------------------
echo "⚙️ Starting full LDAP sync..."
if ! $KCADM create "user-storage/$PROVIDER_ID/sync" -r "$REALM" -s action=triggerFullSync; then
  echo "⚠️ LDAP sync failed. Checking for GroupsMultipleParents issue..."

  # ----------------------------
  # FIX GroupsMultipleParents ISSUE
  # ----------------------------
  echo "🧹 Cleaning up duplicate parent groups..."
  DUP_GROUPS=$($KCADM get groups -r "$REALM" --fields id,name,subGroups --format json | grep -B2 "subGroups" | grep '"id"' | cut -d'"' -f4)

  for GROUP_ID in $DUP_GROUPS; do
    echo "🧩 Fixing group ID: $GROUP_ID"
    # Attempt to clean orphaned subgroups
    $KCADM update groups/$GROUP_ID -r "$REALM" -s subGroups=[] || true
  done

  echo "✅ Group cleanup complete. Retrying sync..."
  $KCADM create "user-storage/$PROVIDER_ID/sync" -r "$REALM" -s action=triggerFullSync
else
  echo "✅ LDAP sync completed successfully."
fi

PARAM='"allowGroupsMultipleParents": ["true"],'
# Check if parameter already exists
if grep -q '"allowGroupsMultipleParents"' "$JSON_FILE"; then
  echo "⚠️  Parameter already exists in $JSON_FILE — skipping update."
  exit 0
fi
# ----------------------------
# INSERT PARAMETER INTO "config" BLOCK
# ----------------------------
echo "🔧 Adding 'allowGroupsMultipleParents' parameter to config..."

# Find line after "config": { and insert our new parameter
# Works even if indentation varies
sed -i '/"config"[[:space:]]*:[[:space:]]*{/{n; s/^/    '"$PARAM"'\n/;}' "$JSON_FILE"
echo "✅ Parameter added successfully to $JSON_FILE"

# ----------------------------
# VERIFY SYNC RESULT
# ----------------------------
echo "🔍 Verifying sync status..."
$KCADM get "user-storage/$PROVIDER_ID/sync" -r "$REALM" | jq .

echo "🎯 Sync verification complete."
















###########
# Usage: ./ldap_full_sync.sh <KEYCLOAK_URL> <REALM> <LDAP_PROVIDER_ID> <ADMIN_USER> <ADMIN_PASS>

KC_URL="$1"
REALM="$2"
PROVIDER_ID="$3"
ADMIN_USER="$4"
ADMIN_PASS="$5"

if [[ -z "$KC_URL" || -z "$REALM" || -z "$PROVIDER_ID" || -z "$ADMIN_USER" || -z "$ADMIN_PASS" ]]; then
  echo "Usage: $0 <KEYCLOAK_URL> <REALM> <LDAP_PROVIDER_ID> <ADMIN_USER> <ADMIN_PASS>"
  exit 1
fi

# Get access token
TOKEN=$(curl -s -X POST "${KC_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASS}" \
  -d 'grant_type=password' \
  -d 'client_id=admin-cli' | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [[ -z "$TOKEN" ]]; then
  echo "❌ Failed to retrieve access token"
  exit 1
fi

echo "✅ Token acquired. Triggering full LDAP sync for provider: $PROVIDER_ID in realm: $REALM"

# Trigger full sync
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "${KC_URL}/admin/realms/${REALM}/user-storage/${PROVIDER_ID}/sync?action=triggerFullSync" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json")

if [[ "$RESPONSE" == "204" ]]; then
  echo "✅ Full LDAP sync triggered successfully."
else
  echo "❌ Failed to trigger sync. HTTP code: $RESPONSE"
fi
