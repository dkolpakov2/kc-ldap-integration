#!/bin/bash
# ============================================
# Keycloak Direct Access Grant + mTLS Setup
# Compatible with bash only (no jq/awk)
# ============================================

KEYCLOAK_BIN="/opt/keycloak/bin/kcadm.sh"
KC_URL="https://keycloak.example.com"
REALM="kafka-ubs-dev"
CLIENT_ID="direct-client-mtls"
USERNAME="user1"
PASSWORD="userpass"
CRT_PATH="/path/to/client.crt"
KEY_PATH="/path/to/client.key"

# --------------------------------------------
# 1️⃣ Login as admin (update credentials below)
# --------------------------------------------
$KEYCLOAK_BIN config credentials --server "$KC_URL" --realm master --user admin --password 'admin_password'

# --------------------------------------------
# 2️⃣ Ensure Realm Exists (create if missing)
# --------------------------------------------
echo " Checking if realm '$REALM' exists..."
REALM_CHECK=$($KEYCLOAK_BIN get realms --fields realm | grep "\"realm\":\"$REALM\"" || true)

if [ -z "$REALM_CHECK" ]; then
  echo " Creating realm '$REALM'..."
  $KEYCLOAK_BIN create realms -s realm="$REALM" -s enabled=true
else
  echo " Realm '$REALM' already exists."
fi

# --------------------------------------------
# 3️⃣ Create Direct Access Client
# --------------------------------------------
echo " Creating client '$CLIENT_ID'..."
$KEYCLOAK_BIN create clients -r "$REALM" \
  -s clientId="$CLIENT_ID" \
  -s protocol=openid-connect \
  -s publicClient=false \
  -s directAccessGrantsEnabled=true \
  -s serviceAccountsEnabled=true \
  -s standardFlowEnabled=false \
  -s 'redirectUris=["*"]'

# --------------------------------------------
# 4️⃣ Get Client UUID (without jq)
# --------------------------------------------
echo " Getting client UUID..."
CLIENTS_JSON=$($KEYCLOAK_BIN get clients -r "$REALM" --fields id,clientId)
# Extract line containing the client
CLIENT_LINE=$(echo "$CLIENTS_JSON" | sed -n "/\"clientId\":\"$CLIENT_ID\"/p")
# Extract the ID value between quotes after "id":
CLIENT_UUID=$(echo "$CLIENT_LINE" | sed 's/.*"id":"\([^"]*\)".*/\1/')

if [ -z "$CLIENT_UUID" ]; then
  echo " Failed to extract CLIENT_UUID. Aborting."
  exit 1
fi

echo " CLIENT_UUID = $CLIENT_UUID"

# --------------------------------------------
# 5️⃣ Encode certificate content
# --------------------------------------------
if [ ! -f "$CRT_PATH" ]; then
  echo " Certificate file not found at $CRT_PATH"
  exit 1
fi

CERT_CONTENT=$(sed ':a;N;$!ba;s/\n/\\n/g' "$CRT_PATH")

# --------------------------------------------
# 6️⃣ Attach Certificate Attributes
# --------------------------------------------
echo " Updating client with certificate attributes..."
$KEYCLOAK_BIN update clients/$CLIENT_UUID -r "$REALM" \
  -s 'attributes."x509.subjectdn"="CN='$CLIENT_ID',O=MyOrg"' \
  -s 'attributes."tls.client.certificate"="'"$CERT_CONTENT"'"'

echo " Certificate attributes added to client."

# --------------------------------------------
# 7️⃣ Test Direct Access Grant via Password
# --------------------------------------------
echo " Testing password-based direct grant..."
curl -k -s -X POST "$KC_URL/realms/$REALM/protocol/openid-connect/token" \
  -d "grant_type=password" \
  -d "client_id=$CLIENT_ID" \
  -d "username=$USERNAME" \
  -d "password=$PASSWORD" | sed 's/{/\n{/g'

# --------------------------------------------
# 8️⃣ (Optional) Test Client Certificate Grant
# --------------------------------------------
echo " Testing mTLS client credentials..."
curl -k --cert "$CRT_PATH" --key "$KEY_PATH" \
  -X POST "$KC_URL/realms/$REALM/protocol/openid-connect/token" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" | sed 's/{/\n{/g'

echo " Done."