#!/bin/bash
set -e
## Settings: clients/<client_id>/client-authenticator-config/{config_id}

REALM="$1"
CLIENT_ID_NAME="$2"

# Keycloak admin command (adjust path if needed)
#KCADM="/opt/keycloak/bin/kcadm.sh --config /tmp/kcadm.config"

if [[ -z "$REALM" || -z "$CLIENT_ID_NAME" ]]; then
    echo "Usage: $0 <realm> <client-id-name>"
    exit 1
fi

echo "Fetching client UUID for $CLIENT_ID_NAME..."

CLIENT_UUID=$($KCADM get clients -r "$REALM" --fields id,clientId \
    | grep "\"clientId\" : \"$CLIENT_ID_NAME\"" \
    | sed -n 's/.*"id" : "\(.*\)".*/\1/p')

if [[ -z "$CLIENT_UUID" ]]; then
    echo "ERROR: Client '$CLIENT_ID_NAME' not found in realm '$REALM'"
    exit 1
fi

echo "Client UUID: $CLIENT_UUID"

# X509 Subject DN Regex
SUBJECT_DN_REGEX='CN=.*, OU=ISS, O="Company", L=.*, ST="Something", C="something"'

echo "Updating X509 settings..."

$KCADM update clients/$CLIENT_UUID -r "$REALM" \
  -s clientAuthenticatorType="x509" \
  -s "attributes.x509.allowRegexPattern=true" \
  -s "attributes.x509.subjectDnRegex=$SUBJECT_DN_REGEX"

if [[ $? -eq 0 ]]; then
    echo "✔ Successfully updated X509 authentication for client '$CLIENT_ID_NAME'"
else
    echo " ERROR updating client"
fi
