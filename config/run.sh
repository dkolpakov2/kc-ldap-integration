#!/usr/bin/env bash
set -euo pipefail

# ---------- VALIDATION ----------
if [[ $# -lt 5 ]]; then
    echo "Usage:"
    echo "  ./run.sh REALM ADMIN_USER_NAME CLIENT_NAME RESOURCE_NAME RESOURCE_SCOPES"
    echo ""
    echo "Example:"
    echo "  ./run.sh ess-kafka admin kafka-broker \"topic:demo-topic\" \"Read Write Describe\""
    exit 1
fi

# ---------- INPUT PARAMS ----------
REALM="$1"
ADMIN_USER="$2"
CLIENT_NAME="$3"
RESOURCE_NAME="$4"
RESOURCE_SCOPES="$5"

echo "=== RUNNING MASTER SCRIPT ==="
echo "REALM            = $REALM"
echo "ADMIN_USER       = $ADMIN_USER"
echo "CLIENT_NAME      = $CLIENT_NAME"
echo "RESOURCE_NAME    = $RESOURCE_NAME"
echo "RESOURCE_SCOPES  = $RESOURCE_SCOPES"
echo "===================================="


# ---------- 1. CREATE CLIENT ----------
echo ""
echo ">>> Running: create-client.sh"
./create-client.sh "$REALM" "$ADMIN_USER" "$keycloak_pass"

# ---------- 2. CREATE SCOPES ----------
echo ""
echo ">>> Running: create-scopes.sh"
./create-scopes.sh "$REALM" "$ADMIN_USER"

# ---------- 3. CREATE RESOURCES ----------
echo ""
echo ">>> Running: create-client-resources.sh"
./create-client-resources.sh "$RESOURCE_NAME" "$RESOURCE_SCOPES" "$ADMIN_USER" "$CLIENT_NAME"

# ---------- 4. CREATE GROUP POLICIES ----------
echo ""
echo ">>> Running: create-group-policy.sh"

# You can pass dynamic policy name & group name OR hardcode it.
POLICY_NAME="dev-cluster-admin"
GROUP_NAME="dev-cluster-admin-group"

./create-group-policy.sh "$REALM" "$ADMIN_USER" "$CLIENT_NAME" "$POLICY_NAME" "$GROUP_NAME"

# ---------- 5. CREATE PERMISSIONS ----------
echo ""
echo ">>> Running: create-permission.sh"

PERMISSION_NAME="cluster-admin-permission"
POLICY_NAME="dev-cluster-admin"
RESOURCE="$RESOURCE_NAME"

./create-permission.sh "$PERMISSION_NAME" "$RESOURCE" "$POLICY_NAME" "$REALM" "$ADMIN_USER"

echo ""
echo "========== ALL TASKS COMPLETED SUCCESSFULLY =========="
