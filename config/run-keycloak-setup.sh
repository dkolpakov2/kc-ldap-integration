#!/bin/bash

# Usage:
# ./run-keycloak-setup.sh <admin_user> <admin_pass> <REALM> <LDAP_NAME> <FLOW_ALIAS>

# Check argument count
if [ "$#" -ne 5 ]; then
  echo "Usage: $0 <admin_user> <admin_pass> <REALM> <LDAP_NAME> <FLOW_ALIAS>"
  exit 1
fi

ADMIN_USER="$1"
ADMIN_PASS="$2"
REALM="$3"
LDAP_NAME="$4"
FLOW_ALIAS="$5"

# File paths
ENCODED_SCRIPT="keycloak-full-setup.sh.b64"
DECODED_SCRIPT="/tmp/keycloak-full-setup.sh"

# Ensure encoded file exists
if [ ! -f "$ENCODED_SCRIPT" ]; then
  echo "Error: Encoded script $ENCODED_SCRIPT not found!"
  exit 2
fi

# Decode the base64 script
base64 --decode "$ENCODED_SCRIPT" > "$DECODED_SCRIPT"
chmod +x "$DECODED_SCRIPT"

echo "Decoded Keycloak setup script to: $DECODED_SCRIPT"
echo "Running setup..."

# Execute the decoded script with parameters
"$DECODED_SCRIPT" "$ADMIN_USER" "$ADMIN_PASS" "$REALM" "$LDAP_NAME" "$FLOW_ALIAS"

# Capture exit status
STATUS=$?

# Secure cleanup
rm -f "$DECODED_SCRIPT"

if [ $STATUS -eq 0 ]; then
  echo "✅ Keycloak setup completed successfully."
else
  echo "❌ Keycloak setup failed with status: $STATUS"
fi

exit $STATUS