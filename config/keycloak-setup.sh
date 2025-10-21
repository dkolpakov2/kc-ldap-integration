#!/bin/bash
set -e
# chmod +x keycloak-setup.sh
# ./keycloak-setup.sh

# ============================================
# GLOBAL CONFIG
# ============================================
KCADM="/opt/keycloak/bin/kcadm.sh"
CONFIG="/tmp/kcadm.config"
SERVER_URL="https://keycloak-dev.example.com"
ADMIN_USER="admin"
ADMIN_PASS="admin123"
MASTER_REALM="master"
REALM="dev-realm"

# ============================================
# LOGIN (only once; config reused across runs)
# ============================================
echo "[INFO] Logging into Keycloak server ..."
$KCADM config credentials \
  --server "$SERVER_URL" \
  --realm "$MASTER_REALM" \
  --user "$ADMIN_USER" \
  --password "$ADMIN_PASS" \
  --config "$CONFIG"

# ============================================
# CREATE REALM (if not exists)
# ============================================
echo "[INFO] Checking realm: $REALM"
EXIST=$($KCADM get realms --config "$CONFIG" | grep -c "\"realm\" : \"$REALM\"" || true)
if [ "$EXIST" -eq 0 ]; then
  echo "[INFO] Creating realm $REALM"
  $KCADM create realms -s realm="$REALM" -s enabled=true --config "$CONFIG"
else
  echo "[INFO] Realm $REALM already exists"
fi

# ============================================
# CREATE CUSTOM AUTH FLOW
# ============================================
FLOW_ALIAS="kafka-direct-grant"
EXIST=$($KCADM get authentication/flows -r "$REALM" --config "$CONFIG" | grep -c "\"alias\" : \"$FLOW_ALIAS\"" || true)
if [ "$EXIST" -eq 0 ]; then
  echo "[INFO] Creating flow: $FLOW_ALIAS"
  $KCADM create authentication/flows \
    -r "$REALM" \
    -s alias="$FLOW_ALIAS" \
    -s description="Kafka Direct Grant flow" \
    -s providerId="basic-flow" \
    --config "$CONFIG"
else
  echo "[INFO] Flow $FLOW_ALIAS already exists"
fi

# ============================================
# BIND FLOW (acts like clicking "Bind Flow")
# ============================================
echo "[INFO] Binding flow: $FLOW_ALIAS"
$KCADM update authentication/flows/$FLOW_ALIAS \
  -r "$REALM" \
  -s "builtIn=false" \
  -s "topLevel=true" \
  --config "$CONFIG"

# ============================================
# ADD EXECUTION TO FLOW
# ============================================
echo "[INFO] Adding execution: X509/Validate Username Form"
$KCADM create authentication/executions \
  -r "$REALM" \
  -s "parentFlow=$FLOW_ALIAS" \
  -s "authenticator=x509-username-form" \
  -s "requirement=ALTERNATIVE" \
  --config "$CONFIG" || echo "[WARN] Execution may already exist"

# ============================================
# LDAP PROVIDER SETUP
# ============================================
LDAP_NAME="ldap-provider"
LDAP_EXIST=$($KCADM get components -r "$REALM" --config "$CONFIG" | grep -c "\"name\" : \"$LDAP_NAME\"" || true)

if [ "$LDAP_EXIST" -eq 0 ]; then
  echo "[INFO] Creating LDAP provider"
  $KCADM create components -r "$REALM" \
    -s name="$LDAP_NAME" \
    -s providerId="ldap" \
    -s providerType="org.keycloak.storage.UserStorageProvider" \
    -s "config.vendor=['ad']" \
    -s "config.connectionUrl=['ldap://ad.example.com:389']" \
    -s "config.usersDn=['OU=Users,DC=example,DC=com']" \
    -s "config.authType=['simple']" \
    -s "config.bindDn=['CN=Administrator,CN=Users,DC=example,DC=com']" \
    -s "config.bindCredential=['Password123']" \
    -s "config.editMode=['READ_ONLY']" \
    -s "config.syncRegistrations=['false']" \
    -s "config.fullSyncPeriod=['-1']" \
    -s "config.changedSyncPeriod=['-1']" \
    -s "config.pagination=['true']" \
    --config "$CONFIG"
else
  echo "[INFO] LDAP provider already exists"
fi

# ============================================
# TRIGGER FULL USER SYNC
# ============================================
echo "[INFO] Running full user sync..."
LDAP_ID=$($KCADM get components -r "$REALM" --config "$CONFIG" | grep -B 1 "\"name\" : \"$LDAP_NAME\"" | grep "\"id\" :" | sed 's/.*: "\(.*\)".*/\1/')
if [ -n "$LDAP_ID" ]; then
  echo "[INFO] LDAP ID: $LDAP_ID"
  $KCADM create user-storage/$LDAP_ID/sync \
    -r "$REALM" \
    -s action=triggerFullSync \
    --config "$CONFIG" || echo "[WARN] Sync may fail if previous run not clean"
else
  echo "[ERROR] Could not detect LDAP ID"
fi

# ============================================
# CLEANUP OR FINAL OUTPUT
# ============================================
echo "[INFO] Keycloak setup complete for realm: $REALM"