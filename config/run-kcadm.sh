#!/bin/bash
#
# run-kcadm.sh — Generic Keycloak admin wrapper
# Usage: ./run-kcadm.sh "<kcadm path + config>" <kcadm args...>
#
# ✅ List realms
# ./run-kcadm.sh "/opt/keycloak/bin/kcadm.sh --config /tmp/kcadm.config" get realms
# ✅ Create user
# ./run-kcadm.sh "/opt/keycloak/bin/kcadm.sh --config /tmp/kcadm.config" create users -r myrealm -s username=test -s enabled=true
# ✅ Update flow
# ./run-kcadm.sh "/opt/keycloak/bin/kcadm.sh --config /tmp/kcadm.config" update authentication/flows/kafka-direct-grant -r myrealm -s description="Updated flow"

# usage: 
# ./run-kcadm.sh get realms
# Define base command (reusable)
KC_BASE_CMD="/opt/keycloak/bin/kcadm.sh --config /tmp/kcadm.config"
# Check if any argument is passed
if [ $# -eq 0 ]; then
  echo "Usage: $0 <kcadm arguments>"
  echo "Example: $0 get realms"
  exit 1
fi
# Compose and execute command
echo "🚀 Running: $KC_BASE_CMD $*"
$KC_BASE_CMD "$@"

# or pass one more param with 
# ===== VALIDATE INPUT =====
if [ $# -lt 2 ]; then
  echo "Usage: $0 \"<kcadm path + config>\" <kcadm args...>"
  echo "Example:"
  echo "  $0 \"/opt/keycloak/bin/kcadm.sh --config /tmp/kcadm.config\" get realms"
  exit 1
fi

# Extract the first parameter as the full kcadm command (with config)
KCADM_CMD="$1"
shift  # Shift arguments so that $@ now holds the rest (actual kcadm args)

echo "🔧 Using command: $KCADM_CMD"
echo "🚀 Executing: $KCADM_CMD $@"

# Run the command safely with eval
eval "$KCADM_CMD $@"

STATUS=$?

if [ $STATUS -eq 0 ]; then
  echo "✅ Command executed successfully."
else
  echo "❌ Command failed with status $STATUS."
fi

exit $STATUS