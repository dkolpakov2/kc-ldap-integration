#!/bin/bash
# ============================================================
# Keycloak Direct Access Grant Client with Bank Certificate
# No jq/awk dependencies — uses sed/grep only
# ============================================================

set -e

KEYCLOAK_BIN="/opt/keycloak/bin/kcadm.sh"
KC_URL="https://keycloak.bank.internal"   
REALM="bank-realm"
CLIENT_ID="Kafka-direct-grant"
BANK_CERT_PATH="/certs/bank-client.crt"
BANK_KEY_PATH="/certs/bank-client.key"
ADMIN_USER="admin"
ADMIN_PASS="admin_password"
TEST_USER="user"
TEST_PASS="pass"

# -----------------------------
# 1️⃣ Login as Keycloak admin
# -----------------------------
echo " Logging into Keycloak admin..."
$KEYCLOAK_BIN config credentials --server "$KC_URL" --realm master --user "$ADMIN_USER" --password "$ADMIN_PASS"

# -----------------------------
# 2️⃣ Create Realm if Missing
# -----------------------------
echo " Checking if realm '$REALM' exists..."
REALM_EXISTS=$($KEYCLOAK_BIN get realms --fields realm | grep "\"realm\":\"$REALM\"" || true)

if [ -z "$REALM_EXISTS" ]; then
  echo " Creating realm '$REALM'..."
  $KEYCLOAK_BIN create realms -s realm="$REALM" -s enabled=true
else
  echo " Realm '$REALM' already exists."
fi

# -----------------------------
# 3️⃣ Create Kafka Direct Grant Client
# -----------------------------
echo "Creating client '$CLIENT_ID'..."
$KEYCLOAK_BIN create clients -r "$REALM" \
  -s clientId="$CLIENT_ID" \
  -s protocol=openid-connect \
  -s publicClient=false \
  -s directAccessGrantsEnabled=true \
  -s serviceAccountsEnabled=true \
  -s standardFlowEnabled=false \
  -s 'redirectUris=["*"]' \
  || echo " Client may already exist, continuing..."

# -----------------------------
# 4️⃣ Extract CLIENT_UUID
# -----------------------------
echo " Extracting client UUID..."
CLIENTS_JSON=$($KEYCLOAK_BIN get clients -r "$REALM" --fields id,clientId)
CLIENT_LINE=$(echo "$CLIENTS_JSON" | sed -n "/\"clientId\":\"$CLIENT_ID\"/p")
CLIENT_UUID=$(echo "$CLIENT_LINE" | sed 's/.*"id":"\([^"]*\)".*/\1/')

if [ -z "$CLIENT_UUID" ]; then
  echo " Could not extract client UUID. Aborting."
  exit 1
fi

echo " CLIENT_UUID: $CLIENT_UUID"

# -----------------------------
# 5️⃣ Read Bank Certificate
# -----------------------------
if [ ! -f "$BANK_CERT_PATH" ]; then
  echo " Bank certificate not found at $BANK_CERT_PATH"
  exit 1
fi

CERT_CONTENT=$(sed ':a;N;$!ba;s/\n/\\n/g' "$BANK_CERT_PATH")

# -----------------------------
# 6️⃣ Attach mTLS Attributes
# -----------------------------
echo " Attaching mTLS (bank certificate) attributes..."
$KEYCLOAK_BIN update clients/$CLIENT_UUID -r "$REALM" \
  -s 'attributes."tls.client.certificate"="'"$CERT_CONTENT"'"' \
  -s 'attributes."x509.subjectdn"="CN=Kafka-direct-grant,O=Bank"' \
  -s 'clientAuthenticatorType=client-x509'

echo " Client updated with certificate attributes."

# -----------------------------
# 7️⃣ Test Token via Password Grant
# -----------------------------
echo " Testing direct grant (username/password)..."
curl -k -s -X POST "$KC_URL/realms/$REALM/protocol/openid-connect/token" \
  -d "grant_type=password" \
  -d "client_id=$CLIENT_ID" \
  -d "username=$TEST_USER" \
  -d "password=$TEST_PASS" | sed 's/{/\n{/g'

# -----------------------------
# 8️⃣ Test Token via Client Certificate (mTLS)
# -----------------------------
if [ -f "$BANK_KEY_PATH" ]; then
  echo " Testing mTLS (client_credentials) flow..."
  curl -k --cert "$BANK_CERT_PATH" --key "$BANK_KEY_PATH" \
    -X POST "$KC_URL/realms/$REALM/protocol/openid-connect/token" \
    -d "grant_type=client_credentials" \
    -d "client_id=$CLIENT_ID" | sed 's/{/\n{/g'
else
  echo " Bank key file not found — skipping mTLS test."
fi

echo " Setup complete for '$CLIENT_ID' in realm '$REALM'."