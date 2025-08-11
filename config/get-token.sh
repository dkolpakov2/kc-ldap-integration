export KC_URL="http://localhost:8080"
export KC_USER="admin"export KC_PASS="admin"
export KC_CLIENT="admin-cli"
export REALM="master"

ACCESS_TOKEN=$(curl -s \
  -d "client_id=${KC_CLIENT}" \
  -d "username=${KC_USER}" \
  -d "password=${KC_PASS}" \
  -d "grant_type=password" \
  "${KC_URL}/realms/master/protocol/openid-connect/token" \
  | jq -r '.access_token')

curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
  "${KC_URL}/admin/realms/${REALM}" | jq .

curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
  "${KC_URL}/admin/realms/${REALM}" | jq .

# list all realms:
curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
  "${KC_URL}/admin/realms" | jq '.[].id'

## output:
# {
#   "id": "myrealm",   <-- Realm ID
#   "realm": "myrealm",
#   "displayName": "My Realm",
#   ...
# }
