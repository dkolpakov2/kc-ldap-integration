#!/bin/bash
# ============================================================
# Keycloak 26 — Auto-create X509 Authentication Flow
# No jq/awk, no temp JSON files — all in-memory vars
# ============================================================

set -euo pipefail

REALM="master"
FLOW_ALIAS="kafka-direct-grant"
FLOW_DESC="Kafka direct grant with X509 username validation"
KCADM="/opt/keycloak/bin/kcadm.sh"
KC_URL="http://localhost:8080"
ADMIN_USER="admin"
ADMIN_PASS="admin"

# --- Login -----------------------------------------------------------------
echo "[INFO] Logging in..."
$KCADM config credentials \
  --server "$KC_URL" \
  --realm master \
  --user "$ADMIN_USER" \
  --password "$ADMIN_PASS"

# --- Get existing flows ----------------------------------------------------
echo "[INFO] Checking existing flows..."
FLOW_LIST=$($KCADM get authentication/flows -r "$REALM")

# --- Does the flow already exist? -----------------------------------------
if echo "$FLOW_LIST" | grep -q "\"alias\" *: *\"$FLOW_ALIAS\""; then
  echo "[INFO] Flow '$FLOW_ALIAS' already exists."
else
  echo "[INFO] Creating new flow '$FLOW_ALIAS'..."
  $KCADM create authentication/flows -r "$REALM" \
    -s alias="$FLOW_ALIAS" \
    -s description="$FLOW_DESC" \
    -s providerId=basic-flow \
    -s topLevel=true \
    -s builtIn=false
  echo "[INFO] Flow created."
fi

# --- Refresh flow list -----------------------------------------------------
FLOW_LIST=$($KCADM get authentication/flows -r "$REALM")

# --- Extract FLOW_ID -------------------------------------------------------
FLOW_ID=$(echo "$FLOW_LIST" \
  | sed -nE "/\"alias\" *: *\"$FLOW_ALIAS\"/I{N;N;N;N;/\"id\"/s/.*\"id\" *: *\"([^\"]+)\".*/\1/p}" \
  | head -1)

if [ -z "$FLOW_ID" ]; then
  echo "[ERROR] Could not find flow ID for '$FLOW_ALIAS'."
  exit 1
fi
echo "[INFO] Flow ID: $FLOW_ID"

# --- Get available providers ----------------------------------------------
PROVIDERS=$($KCADM get authentication/providers -r "$REALM")

if ! echo "$PROVIDERS" | grep -q '"id" *: *"x509-username"'; then
  echo "[ERROR] X509 provider not found. Start Keycloak with:"
  echo "        KC_FEATURES=x509"
  exit 1
fi
echo "[INFO] X509 provider available."

# --- Check if execution already exists ------------------------------------
EXECUTIONS=$($KCADM get authentication/flows/"$FLOW_ALIAS"/executions -r "$REALM")

if echo "$EXECUTIONS" | grep -q '"providerId" *: *"x509-username"'; then
  echo "[INFO] X509 execution already attached to flow '$FLOW_ALIAS'."
else
  echo "[INFO] Adding X509/Validate Username execution..."
  $KCADM create authentication/executions \
    -r "$REALM" \
    -s provider=x509-username \
    -s parentFlow="$FLOW_ALIAS" \
    -s requirement=REQUIRED
fi

# --- Verify final setup ---------------------------------------------------
EXEC_CHECK=$($KCADM get authentication/flows/"$FLOW_ALIAS"/executions -r "$REALM")
if echo "$EXEC_CHECK" | grep -q '"providerId" *: *"x509-username"'; then
  echo "[SUCCESS] Flow '$FLOW_ALIAS' has X509/Validate Username execution attached."
else
  echo "[WARN] X509 step not visible after creation."
fi
