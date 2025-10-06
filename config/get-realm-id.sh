#!/bin/bash
set -e

# Input realm name
REALM_NAME="kafka-usb-dev"

# Login to Keycloak (update values as needed)
export KC_ADMIN_USER="admin"
export KC_ADMIN_PASS="admin_password"
export KC_HOST="http://localhost:8080"
export KC_REALM="master"

# Login to Keycloak
/opt/keycloak/bin/kcadm.sh config credentials --server "$KC_HOST" --realm "$KC_REALM" --user "$KC_ADMIN_USER" --password "$KC_ADMIN_PASS"

# option to use grep/sed
# Get raw JSON list of realms
REALMS_JSON=$(/opt/keycloak/bin/kcadm.sh get realms --fields id,realm)

# Extract the line with our realm
# Remove spaces and quotes for easier parsing
CLEANED=$(echo "$REALMS_JSON" | tr -d ' ' | tr -d '"' )
CLEANED=$(echo "$CLEANED" | tr -d '\r' | tr -d ' ')

#This makes sure hyphens (-) and dots (.) are treated literally.
ESCAPED_REALM=$(printf '%s\n' "$REALM_NAME" | sed 's/[][\.^$*\/]/\\&/g')
REALM_ID=$(printf '%s\n' "$CLEANED" | sed -n "/$ESCAPED_REALM/p" | cut -d',' -f2)
# OR if JSON cleaned
REALM_ID=$(printf '%s\n' "$CLEANED" |
  sed -n "/\"realm\": *\"$ESCAPED_REALM\"/{N; s/.*\"id\": *\"\([^\"]*\)\".*/\1/p}"
)

# Find matching realm block and extract id
# Example input: [{"id":"master","realm":"master"},{"id":"kafka-usb-dev","realm":"kafka-usb-dev"}]
REALM_ID=$(echo "$CLEANED" | sed -n "s/.*id:\([^,}]*\),realm:$REALM_NAME.*/\1/p")

#if If "id" comes before "realm", swap search order:
REALM_ID=$(printf '%s\n' "$CLEANED" |
  sed -n "/\"id\":/{N;/\"realm\": *\"$ESCAPED_REALM\"/s/.*\"id\": *\"\([^\"]*\)\".*/\1/p}"
)
# if CLEANED like below:
{
  "id": "12345-abcde",
  "realm": "kafka-dev"
}
## USe this:
REALM_NAME="kafka-dev"
ESCAPED_REALM=$(printf '%s\n' "$REALM_NAME" | sed 's/[][\.^$*\/]/\\&/g')

REALM_ID=$(printf '%s\n' "$CLEANED" |
  sed -n "/\"realm\": *\"$ESCAPED_REALM\"/{N; s/.*\"id\": *\"\([^\"]*\)\".*/\1/p}"
)
echo "Realm ID: $REALM_ID"
## 
REALM_NAME="kafka-usb-dev"
CLEANED='[{"id":"123456005","realm":"master"},{"id":"0987656001","realm":"kafka-usb-dev"}]'

REALM_ID=$(printf '%s\n' "$CLEANED" | sed -n "s/.*\"id\":\"\([^\"]*\)\"[^{]*\"realm\":\"$REALM_NAME\".*/\1/p")

echo "Realm ID: $REALM_ID"

## 3 Version with bash script only:
REALM_ID=""
while IFS=, read -r name id; do
  if [ "$name" = "$REALM_NAME" ]; then
    REALM_ID="$id"
    break
  fi
done < realms.csv
echo "Realm ID: $REALM_ID"

## Update parentId for ldap-provider-dev.json
sed -i "s/\"parentId\": *\"changeme\"/\"parentId\": \"$REALM_ID\"/" ldap-provider.json



if [ -z "$REALM_ID" ]; then
  echo "❌ Realm '$REALM_NAME' not found."
  exit 1
else
  echo "✅ Realm '$REALM_NAME' ID: $REALM_ID"
fi




# By USing JQ
# Fetch the realm list and extract the ID for the given name
REALM_ID=$(/opt/keycloak/bin/kcadm.sh get realms --fields id,realm | jq -r --arg realm "$REALM_NAME" '.[] | select(.realm==$realm) | .id')

if [ -z "$REALM_ID" ]; then
  echo "❌ Realm '$REALM_NAME' not found."
  exit 1
else
  echo "✅ Realm '$REALM_NAME' ID: $REALM_ID"
fi


## Inject LDAP-ID
# 1️⃣ Get component list as JSON
RAW=$(/opt/keycloak/bin/kcadm.sh get components -r "$REALM" --fields name,id)

# 2️⃣ Clean and normalize output (remove newlines/spaces)
CLEANED=$(echo "$RAW" | tr -d '\n' | tr -d '[:space:]')

# Example cleaned output:
# [{"id":"abc-123","name":"ldap-provider-dev"},{"id":"xyz-999","name":"other"}]

# 3️⃣ Extract ID for ldap-provider-dev using sed
LDAP_PROVIDER_ID=$(echo "$CLEANED" | sed -n "s/.*{\"id\":\"\([^\"]*\)\",\"name\":\"$COMPONENT_NAME\".*/\1/p")

# 4️⃣ Validate extraction
if [ -z "$LDAP_PROVIDER_ID" ]; then
  echo "❌ Could not find LDAP provider ID for '$COMPONENT_NAME' in realm '$REALM'"
  exit 1
fi

echo "✅ Found LDAP_PROVIDER_ID=$LDAP_PROVIDER_ID"

# 5️⃣ Inject into JSON file
sed -i "s/\"parentId\": *\"changeme\"/\"parentId\": \"$LDAP_PROVIDER_ID\"/" "$JSON_FILE"

echo "✅ Updated $JSON_FILE with parentId=$LDAP_PROVIDER_ID"