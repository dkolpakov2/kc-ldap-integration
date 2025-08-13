LDAP_PROVIDER_ID=$(/opt/keycloak/bin/kcadm.sh get components -r master --query 'name=AD LDAP' --fields id --format csv | tail -n +2)
# how to remove double quotas from file by using ded command
LDAP_PROVIDER_ID=$(/opt/keycloak/bin/kcadm.sh get components -r master --query 'name=AD LDAP' --fields id --format csv \
    | grep -v '^id' \
    | grep ldap \
    | cut -d',' -f1 )

# JSON integration with ldap-groups.json
LDAP_PROVIDER_ID=$(./kcadm.sh get components -r master \
    --query 'name=ldap' --fields id --format csv | tail -n +2 | cut -d, -f1)

sed -i "s/PUT_YOUR_LDAP_PROVIDER_ID_HERE/$LDAP_PROVIDER_ID/" ldap-group-config.json

./kcadm.sh create components -r master -f ldap-group-config.json

# CSV integration TODO: fix  it
# /opt/keycloak/bin/kcadm.sh create components -r master \
#   -s name="ad-group-mapper" \
#   -s providerId=group-ldap-mapper \
#   -s providerType=org.keycloak.storage.ldap.mappers.LDAPStorageMapper \
#   -s parentId=$LDAP_PROVIDER_ID \
#   -s 'config.groups.dn=["OU=Groups,DC=example,DC=com"]' \
#   -s 'config.group.name.ldap.attribute=["cn"]' \
#   -s 'config.group.object.classes=["group"]' \
#   -s 'config.preserve.group.inheritance=["true"]' \
#   -s 'config.ignore.missing.groups=["false"]' \
#   -s 'config.members.ldap.attribute=["member"]' \
#   -s 'config.ldap.filter=["(objectClass=group)"]' \
#   -s 'config.mode=["READ_ONLY"]'


# trigger LDAP full sync
/opt/keycloak/bin/kcadm.sh create user-storage/$LDAP_PROVIDER_ID/sync?action=triggerFullSync -r master

# trigger LDAP sync update
/opt/keycloak/bin/kcadm.sh create user-storage/$LDAP_PROVIDER_ID/sync?action=triggerChangedUsersSync -r master

# verify groups:
/opt/keycloak/bin/kcadm.sh get groups -r master --format csv > groups.csv
cat groups.csv

#check users in groups:
GROUP_ID=$(/opt/keycloak/bin/kcadm.sh get groups -r master --query name=YourGroupName --fields id --format csv | tail -n +2)
/opt/keycloak/bin/kcadm.sh get groups/$GROUP_ID/members -r master --format csv

echo "GROUP_ID validate: $GROUP_ID"

