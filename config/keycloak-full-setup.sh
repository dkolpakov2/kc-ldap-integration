#!/bin/bash
set -e

#Usage:
# chmod +x keycloak-full-setup.sh
# ./keycloak-full-setup.sh
# |Step| Description                                                |
# |----| ---------------------------------------------------------- |
# |    | Logs in via global config                                  |
# |    | Creates realm if missing                                   |
# |    | Creates + binds custom auth flow                           |
# |    | Adds “X509/Validate Username Form” execution               |
# |    | Creates LDAP provider                                      |
# |    | Creates Group Mapper (with multiple parents & inheritance) |
# |    | Triggers full sync with retry logic                        |
# |    | No jq/awk usage — pure Bash + sed/grep                     |
# ===================================================================
# GLOBAL CONFIG
# ===================================================================
KCADM="/opt/keycloak/bin/kcadm.sh"
CONFIG="/tmp/kcadm.config"
SERVER_URL="https://keycloak-dev.example.com"
ADMIN_USER="admin"

ADMIN_PASS="admin123"
ENCODED=$(echo -n "$ADMIN_PASS" | base64)
echo "Base64 encoded: $ENCODED"
DECODED=$(echo "$ENCODED" | base64 --decode)
echo "Decoded password: $DECODED"

export LDAP_PASS_B64=$(echo -n "LdapSecret!" | base64)
LDAP_PASS=$(echo "$LDAP_PASS_B64" | base64 --decode)

MASTER_REALM="master"
REALM="dev-realm"
LDAP_NAME="ldap-provider"
FLOW_ALIAS="kafka-direct-grant"

# ============================================================
# LOGIN
# ============================================================
echo "[INFO] Logging into Keycloak..."
$KCADM config credentials \
  --server "$SERVER_URL" \
  --realm "$MASTER_REALM" \
  --user "$ADMIN_USER" \
  --password "$ADMIN_PASS" \
  --config "$CONFIG"

# ============================================================
# CREATE REALM (if missing)
# ============================================================
if ! $KCADM get realms --config "$CONFIG" | grep -q "\"realm\" : \"$REALM\""; then
  echo "[INFO] Creating realm $REALM"
  $KCADM create realms -s realm="$REALM" -s enabled=true --config "$CONFIG"
else
  echo "[INFO] Realm $REALM already exists"
fi

# ============================================================
# CREATE AUTH FLOW
# ============================================================
if ! $KCADM get authentication/flows -r "$REALM" --config "$CONFIG" | grep -q "\"alias\" : \"$FLOW_ALIAS\""; then
  echo "[INFO] Creating flow: $FLOW_ALIAS"
  $KCADM create authentication/flows \
    -r "$REALM" \
    -s alias="$FLOW_ALIAS" \
    -s description="Kafka Direct Grant Flow" \
    -s providerId="basic-flow" \
    --config "$CONFIG"
else
  echo "[INFO] Flow $FLOW_ALIAS already exists"
fi

# ============================================================
# BIND FLOW (acts like clicking “Bind Flow”)
# ============================================================
echo "[INFO] Binding flow: $FLOW_ALIAS"
$KCADM update authentication/flows/$FLOW_ALIAS \
  -r "$REALM" \
  -s "builtIn=false" \
  -s "topLevel=true" \
  --config "$CONFIG"

# ============================================================
# ADD EXECUTION (X509/Validate Username Form)
# ============================================================
echo "[INFO] Adding execution: X509/Validate Username Form"
$KCADM create authentication/executions \
  -r "$REALM" \
  -s "parentFlow=$FLOW_ALIAS" \
  -s "authenticator=x509-username-form" \
  -s "requirement=ALTERNATIVE" \
  --config "$CONFIG" || echo "[WARN] Execution may already exist"

# ============================================================
# CREATE LDAP PROVIDER
# ============================================================
if ! $KCADM get components -r "$REALM" --config "$CONFIG" | grep -q "\"name\" : \"$LDAP_NAME\""; then
  echo "[INFO] Creating LDAP provider: $LDAP_NAME"
  $KCADM create components -r "$REALM" \
    -s name="$LDAP_NAME" \
    -s providerId="ldap" \
    -s providerType="org.keycloak.storage.UserStorageProvider" \
    -s "config.vendor=['ad']" \
    -s "config.connectionUrl=['ldap://ad.example.com:389']" \
    -s "config.usersDn=['OU=Users,DC=example,DC=com']" \
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

# ============================================================
# GET LDAP ID
# ============================================================
LDAP_ID=$($KCADM get components -r "$REALM" --config "$CONFIG" | grep -B 1 "\"name\" : \"$LDAP_NAME\"" | grep "\"id\" :" | sed 's/.*: "\(.*\)".*/\1/')
if [ -z "$LDAP_ID" ]; then
  echo "[ERROR] Failed to get LDAP ID. Exiting."
  exit 1
fi
echo "[INFO] LDAP ID: $LDAP_ID"

# ============================================================
# CREATE LDAP GROUP MAPPER (if missing)
# ============================================================
GROUP_MAPPER="ldap-group-mapper"
if ! $KCADM get components -r "$REALM" --config "$CONFIG" | grep -q "\"name\" : \"$GROUP_MAPPER\""; then
  echo "[INFO] Creating LDAP Group Mapper"
  $KCADM create components -r "$REALM" \
    -s name="$GROUP_MAPPER" \
    -s providerId="group-ldap-mapper" \
    -s providerType="org.keycloak.storage.ldap.mappers.LDAPStorageMapper" \
    -s parentId="$LDAP_ID" \
    -s "config.groupNameLDAPAttribute=['cn']" \
    -s "config.groupObjectClasses=['group']" \
    -s "config.groupsDn=['OU=Groups,DC=example,DC=com']" \
    -s "config.mode=['READ_ONLY']" \
    -s "config.membershipLDAPAttribute=['member']" \
    -s "config.membershipAttributeType=['DN']" \
    -s "config.groupsPath=['/']" \
    -s "config.preserveGroupInheritance=['true']" \
    -s "config.ignoreMissingGroups=['false']" \
    -s "config.membershipUserLDAPAttribute=['distinguishedName']" \
    -s "config.GroupsMultipleParents=['true']" \
    --config "$CONFIG"
else
  echo "[INFO] Group mapper already exists"
fi

# ============================================================
# TRIGGER FULL SYNC (with retry)
# ============================================================
echo "[INFO] Triggering full user sync..."
SYNC_RESULT=$($KCADM create user-storage/$LDAP_ID/sync \
  -r "$REALM" \
  -s action=triggerFullSync \
  --config "$CONFIG" 2>&1 || true)

if echo "$SYNC_RESULT" | grep -q "Unknown error"; then
  echo "[WARN] Initial sync failed — waiting 15s before retry..."
  sleep 15
  echo "[INFO] Retrying full user sync..."
  $KCADM create user-storage/$LDAP_ID/sync \
    -r "$REALM" \
    -s action=triggerFullSync \
    --config "$CONFIG" || echo "[ERROR] Sync retry failed"
else
  echo "[INFO] Full sync completed successfully"
fi

echo "[SUCCESS] ✅ Keycloak full setup completed for realm: $REALM"
