# kc-ldap-integration
# GIT create a new repository on the command line
echo "# kc-ldap-integration" >> README.md
git init
git add README.md
git commit -m "first commit"
git branch -M master
git remote add origin https://github.com/git-account/kc-ldap-integration.git
git push -u origin master
…or push an existing repository from the command line
git remote add origin https://github.com/git-account/kc-ldap-integration.git
git branch -M master
git push -u origin master

==========================================================
Fix kcadm.sh ERROR:
Invalid user credentials [invalid_grant]
❗ User is enabled, but Direct Access Grants are disabled
  Keycloak ONLY allows password grant if:
  Direct Access Grants Enabled = ON
  Check this:
Clients → admin-cli → Settings
  Should be:
    Direct Access Grants Enabled = ON
----------------
Fix via kcadm:

ADMIN_CLI_ID=$(/opt/keycloak/bin/kcadm.sh get clients -r master -q clientId=admin-cli | grep '"id"' | head -1 | sed 's/.*"id" : "\(.*\)".*/\1/')
/opt/keycloak/bin/kcadm.sh update clients/$ADMIN_CLI_ID -r master -s 'directAccessGrantsEnabled=true'

✅ Fix (run inside a Keycloak pod — no curl, no jq)
1️⃣ Assign the missing realm role:
/opt/keycloak/bin/kcadm.sh add-roles \
  --uusername admin-dk \
  --rolename realm-admin \
  -r master

2️⃣ Assign required client roles:
/opt/keycloak/bin/kcadm.sh add-roles \
  --uusername admin-dk \
  --cclientid realm-management \
  --rolename realm-admin \
  -r master

3️⃣ Retry login:
kcadm.sh config credentials \
  --server "$KEYCLOAK_URL" \
  --realm master \
  --user admin-dk \
  --password "$ADMIN_PASS"

==========================================================
Simulate LDAP Login via Script
==========================================================

0.  docker-compose -f docker-compose-ldap.yaml up --build
Access URLs
Service	     | URL	                    |Default Credentials
-----------------------------------------------------------------------
Keycloak	    http://localhost:8080	    admin / admin
phpLDAPadmin	https://localhost:6443	cn=admin,dc=example,dc=org / admin
------------------------------------------------------------------------
Keycloak LDAP Federation Setup
  In Keycloak Admin UI:
    Go to User Federation → Add provider → ldap
    Use:
      Vendor: Other
      Connection URL: ldap://openldap:389
      Users DN: dc=example,dc=org
      Bind DN: cn=admin,dc=example,dc=org
      Bind Credential: admin
      Click "Test Connection", then "Test Authentication"
      Save and hit "Synchronize all users"



1. Simulate Script simulate-ldap-login-with-sync.sh Does 4 steps ( comments included)
    - Logs into Keycloak as an admin
    - Calls the LDAP user sync API
    - Tries to log in using an LDAP user
    - Prints a truncated access token if successful
2. Run script:
    >>bash:
    chmod +x simulate-ldap-login-with-sync.sh  # enable process
    ./simulate-ldap-login-with-sync.sh

-------------------------------------------------------
1. Integration with Postman or K6 for load testing
2. Docker container to simulate this
3. Kubernetes Job/CronJob YAML to run it inside AKS
-------------------------------------------------------
Postman load test:
1. create POST request:
    >> bash:
    POST {{keycloak_url}}/realms/{{realm_name}}/protocol/openid-connect/token
2. Body (x-www-form-urlencoded):
    client_id=account
    grant_type=password
    username={{ldap_user}}
    password={{ldap_password}}

3. Postman Collection Example (JSON Export)
{
  "info": {
    "name": "Keycloak LDAP Login Test",
    "_postman_id": "uuid-here",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [{
    "name": "LDAP Login",
    "request": {
      "method": "POST",
      "header": [{
        "key": "Content-Type",
        "value": "application/x-www-form-urlencoded"
      }],
      "body": {
        "mode": "urlencoded",
        "urlencoded": [
          { "key": "client_id", "value": "account", "type": "text" },
          { "key": "grant_type", "value": "password", "type": "text" },
          { "key": "username", "value": "{{ldap_user}}", "type": "text" },
          { "key": "password", "value": "{{ldap_password}}", "type": "text" }
        ]
      },
      "url": {
        "raw": "{{keycloak_url}}/realms/{{realm_name}}/protocol/openid-connect/token",
        "host": ["{{keycloak_url}}"],
        "path": ["realms", "{{realm_name}}", "protocol", "openid-connect", "token"]
      }
    },
    "response": []
  }]
}

4. Load Testing with Postman + Newman
To simulate load, use Newman:
>>bash
    npm install -g newman

newman run keycloak-ldap-login.postman_collection.json \
  --env-var "keycloak_url=http://localhost:8080" \
  --env-var "realm_name=master" \
  --env-var "ldap_user=ldapuser1" \
  --env-var "ldap_password=Password123!"    
-----------
5. Create LDAP User via Keycloak Admin API
    POST /admin/realms/{{realm}}/users
    Authorization: Bearer {{admin_token}}
    Content-Type: application/json
    BODY:
    {
        "username": "{{ldap_user}}",
        "enabled": true,
        "emailVerified": true,
        "email": "{{ldap_user}}@test.com",
        "credentials": [{
            "type": "password",
            "value": "{{ldap_password}}",
            "temporary": false
        }]
    }
>>!!!     This does not create the user in the LDAP directory itself — only in Keycloak unless sync mode = IMPORT.
-  Login using LDAP Credentials (same in step 1. )
-  Decode JWT Token (Optional)
    Use Postman Tests tab with:
    >>JS:
    const jwt = pm.response.json().access_token;
    const payload = JSON.parse(atob(jwt.split('.')[1]));
    console.log("Token Payload:", payload);
    pm.environment.set("user_id", payload.sub);
-    Call a Protected API
    GET /my-protected-api
    Authorization: Bearer {{user_token}}
- Automate with Newman (CLI)
>>bash:
    newman run keycloak-ldap-chain.postman_collection.json \
  --env-var "realm=demo" \
  --env-var "keycloak_url=http://localhost:8080" \
  --env-var "ldap_user=test123" \
  --env-var "ldap_password=Test123@" \
  --env-var "client_id=my-client"
--------------------------------------------------------------
6. Optional: Use a Mock LDAP Server
For local testing without a real LDAP:
>>bash:
  docker run --name mock-ldap -p 389:389 -e SLAPD_DOMAIN="example.org" -e SLAPD_PASSWORD="admin" osixia/o

## ERROR
keycloak Error when trying to connect to LDAP: 'SocketReset'

## Create a Sample JKS File for Keycloak to enable SSL/https:8443
keytool -genkeypair -alias keycloak -keyalg RSA -keysize 2048 \
  -keystore my-keystore.jks -storepass changeit \
  -validity 365 -dname "CN=localhost,OU=IT,O=Example,L=City,S=State,C=US"
##  Generate Java Keystore (JKS) Truststore for LDAP
If using self-signed certs for the LDAP simulator (e.g., rroemhild/test-openldap), we need to extract its cert and trust it.
## use script:
# Export LDAP cert from running container (after starting docker-compose once)
docker cp ldap:/etc/ssl/certs/ca.crt ldap-ca.crt

# Import cert into JKS truststore
keytool -importcert -trustcacerts -keystore ldap-truststore.jks \
  -storepass changeit -noprompt \
  -alias testldap -file ldap-ca.crt
-----------------------------------------  
 Folder Structure:
.
├── Dockerfile
├── docker-compose.yml
├── kc-keystore.jks            # HTTPS server cert for Keycloak
├── ldap-truststore.jks        # Truststore to trust LDAP over SSL

docker build -t Rubtsovsk1234!SachSachkeycloak-with-yum .
docker run -p 8443:8443 keycloak-with-yum

## Test LDAP Connection:
>>bash:
openssl s_client -connect ldap:636

## verify in container:
docker exec -it keycloak openssl version

## Troubleshooting steps
# Check if the file exists in the container
docker exec -it <keycloak-container> ls -l /etc/x509/https/

# Test permissions
docker exec -it <keycloak-container> ls -ld /etc/x509 /etc/x509/https
docker exec -it keycloak_container /bin/b
# Validate Keystore.JKS

# List Runing Dockers
docker ps -q --filter "name=^/keycloak$"

>>>>>============================================
Deploy manually after KC is up:
  docker compose up -d keycloak
# Wait until keycloak is up, then run the script inside the container
  docker exec -it <keycloak-container-name> bash /opt/keycloak/configure-ldap.sh
78  
# -u 0 runs the command as root user. Once you're in:
docker exec -u 0 -it <container_name_or_id> /bin/sh
su - keycloak   //  back to KC user
docker exec -u 0 <container_name> touch /root/test.txt
docker exec -u keycloak <container_name> ls -la
docker exec <container_name> whoami


<<<<<<<<<<<>>>>>>>>>>>
call docker 
docker run --name keycloak \
  -e KEYCLOAK_ADMIN=admin \
  -e KEYCLOAK_ADMIN_PASSWORD=admin \
  -p 8080:8080 \
  quay.io/keycloak/keycloak:24.0.1 \
  start-dev
==========================================
>> Dockerfile:
    FROM quay.io/keycloak/keycloak:24.0.1

    # Set workdir for scripts
    WORKDIR /opt/keycloak

    # Copy  custom entrypoint script
    COPY entrypoint.sh /opt/keycloak/entrypoint.sh
    RUN chmod +x /opt/keycloak/entrypoint.sh

    # Pre-build the Keycloak distribution (required for running commands in custom images)
    RUN /opt/keycloak/bin/kc.sh build

    # Use  custom entrypoint
    ENTRYPOINT ["/opt/keycloak/entrypoint.sh"]
------------------------------------------
>> entrypoint.sh
----------------
  FROM quay.io/keycloak/keycloak:24.0.1
  # Set workdir for scripts
  WORKDIR /opt/keycloak
  # Copy  custom entrypoint script
  COPY entrypoint.sh /opt/keycloak/entrypoint.sh
  RUN chmod +x /opt/keycloak/entrypoint.sh
  # Pre-build the Keycloak distribution (required for running commands in custom images)
  RUN /opt/keycloak/bin/kc.sh build
  # Use  custom entrypoint
  ENTRYPOINT ["/opt/keycloak/entrypoint.sh"]
-----------------------------------------
# Start Keycloak  >>>>>>>>>>>>>>>>>>>>>>>>
#!/usr/bin/env sh

echo "Starting Keycloak..."

# Example: Import LDAP configuration JSON if exists
if [ -f "/opt/keycloak/configure-ldap.json" ]; then
  echo "Importing LDAP config..."
  /opt/keycloak/bin/kc.sh import --dir=/opt/keycloak/configure-ldap.json || echo "LDAP import failed or skipped"
fi

# Start Keycloak
exec /opt/keycloak/bin/kc.sh start-dev

----------------------------------------
run-in-keycloak.sh (example script)
>>sh
#!/bin/sh
# Define the container name
CONTAINER_NAME="keycloak"
# Get the running container ID (partial name match)
CONTAINER_ID=$(docker ps -qf "name=$CONTAINER_NAME")

# Check if container was found
if [ -z "$CONTAINER_ID" ]; then
  echo "Container with name '$CONTAINER_NAME' not found or not running."
  exit 1
fi

echo "Found container: $CONTAINER_ID"

# Example: Run a command inside the container
docker exec "$CONTAINER_ID" ls /opt/keycloak

## Then run the command via docker exec:
>>bash
docker exec -it keycloak \
  /opt/keycloak/bin/kcadm.sh config truststore \
  --truststore /opt/keycloak/certs/ldap-cert.pem \
  --truststore-type PEM
-----------------------------------------
├── Dockerfile
├── docker-compose.yml
├── my-keystore.jks             # HTTPS keystore
├── ldap-truststore.jks         # LDAP truststore
└── healthcheck.sh              # Optional: validate LDAP on boot

-----------------------------------------
# Install OpenSSL without microdnf
RUN yum install -y openssl nss-tools ca-certificates && yum clean all

# Create HTTPS cert folder and copy keystores
RUN mkdir -p /etc/x509/https/
COPY my-keystore.jks /etc/x509/https/
COPY truststore.jks /etc/x509/https/

# Optional: copy healthcheck
COPY healthcheck.sh /opt/keycloak/tools/healthcheck.sh
RUN chmod +x /opt/keycloak/tools/healthcheck.sh

# Check keystore
keytool -list -v -keystore keystore.jks -alias myalias
#docker compose up -d keycloak

# Wait until keycloak is up, then run the script inside the container
docker exec -it <keycloak-container-name> bash /opt/keycloak/configure-ldap.sh

-----------------------------------------
User:
  dmitry: 3b7f0b48-5b08-4ab8-b34f-2e866a7325df
  pass: admin
-------------------------------------------------------------

## 2nd method= import realm

===================================================================
## 3 Import Groups:
 >> Pre-requisites
  - Keycloak already has an LDAP User Federation provider set up and working.
  - LDAP contains group objects, e.g. cn=admins,ou=Groups,dc=example,dc=com
  -  LDAP user objects have membership attributes like memberOf or group entries contain member attributes.
  - Add Group Mapper in Keycloak Admin Console
    Go to:
      - User Federation → < LDAP provider name> → Mappers → Create
      - Fill in the mapper details:
      - Name: LDAP Group Mapper
      - Mapper Type: group-ldap-mapper

LDAP Groups DN:
Path to groups in LDAP. Example:

----------------------------
API/CLI Automation
If you want this mapping to be created via script (Docker/Kubernetes friendly), you can use kcadm.sh:

>>bash
REALM=myrealm
LDAP_PROVIDER_ID=$(/opt/keycloak/bin/kcadm.sh get components -r $REALM --query 'providerId=ldap' --fields id --format csv | tail -n1)

cat <<EOF | /opt/keycloak/bin/kcadm.sh create components -r $REALM -s name=ldap-group-mapper -s providerId=group-ldap-mapper -s providerType=org.keycloak.storage.ldap.mappers.LDAPStorageMapper -s parentId=$LDAP_PROVIDER_ID -s config.'ldap.groups.dn'=["ou=Groups,dc=example,dc=com"] -s config.'group.name.ldap.attribute'=["cn"] -s config.'group.object.classes'=["groupOfNames"] -s config.'membership.ldap.attribute'=["member"] -s config.'membership.attribute.type'=["DN"] -s config.'mode'=["READ_ONLY"] -s config.'groups.path'=["/"]
{}
EOF

--------------
Group LDAP Mapper:
--------------
{
  "name": "groups",
  "providerId": "group-ldap-mapper",
  "parentId": "LDAP_PROVIDER_ID",
  "config": {
    "groups.dn": ["ou=groups,dc=example,dc=com"],
    "group.name.ldap.attribute": ["cn"],
    "group.object.classes": ["groupOfNames"],
    "preserve.group.inheritance": ["true"],
    "ignore.missing.groups": ["false"],
    "mapped.group.attributes": [""],
    "membership.ldap.attribute": ["member"],
    "membership.attribute.type": ["DN"],
    "membership.user.ldap.attribute": ["uid"],
    "ldap.filter": [""],
    "mode": ["READ_ONLY"],
    "groups.path": ["/"],
    "drop.non.existing.groups.during.sync": ["false"]
    {
  "name": "group-mapper",
  "providerId": "group-ldap-mapper",
  "providerType": "org.keycloak.storage.ldap.mappers.LDAPStorageMapper",
  "parentId": "${LDAP_PROVIDER_ID_changeme}",
  "config": {
    "groups.dn": ["OU=Groups,DC=dev3,DC=com, DC=net"],
    "group.name.ldap.attribute": ["cn"],
    "group.object.classes": ["group"],
    "preserve.group.inheritance": ["false"],
    "ignore.missing.groups": ["true"],
    "membership.ldap.attribute": ["member"],
    "membership.attribute.type": ["DN"],
    "membership.user.ldap.attribute": ["DN"],
    "mode": ["READ_ONLY"],
,
    "mapped.group.attributes": ["memberOf"],
    "drop.non.existing.groups.during.sync": ["true"],
    "groups.path": ["/"],
    "memberof.ldap.attribute": ["memberOf"],
    "multiple.parents.allowed": ["false"]   <--- 🔑 Important!
  }
}

#### Login to the correct realm with admin privileges
>> Prerequisite: admin user in my-realm-dev exists:
### This user must have the realm-admin role inside the realm-management client of my-realm-dev.
### We assign it in the Admin Console:
  my-realm-dev → 
          Clients → 
              realm-management → Roles → realm-admin → Assign to admin user.

>> bash
./kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm my-realm-dev \
  --user my-admin-user \
  --password 'my-password'


=====================================================
## Select ENV: Pass as script argument

#!/bin/bash
MODE="$1"

if [ "$MODE" = "prod" ]; then
    echo "Production mode"
elif [ "$MODE" = "dev" ]; then
    echo "Development mode"
else
    echo "Usage: $0 [prod|dev]"
    exit 1
fi
-------------------------
Run:

./myscript.sh prod
./myscript.sh dev
======================================================


3️⃣ Clean Up Duplicate Users Before Sync

If you want LDAP to import fresh, remove conflicting accounts:

./kcadm.sh get users -r master --query email=duplicate@example.com --fields id,username,email --format csv \
  | tail -n +2 \
  | while read id; do
      ./kcadm.sh delete users/$id -r master
    done
### wipe all users (except admin) before sync:

./kcadm.sh get users -r master --fields id,username --format csv \
  | grep -v admin \
  | tail -n +2 \
  | while read id; do
      ./kcadm.sh delete users/$id -r master
    done    

###
LDAP_PROVIDER_ID=$(./kcadm.sh get components -r master \
    --query 'name=ldap' --fields id --format csv | tail -n +2 | cut -d, -f1)

sed -i "s/PUT__LDAP_PROVIDER_ID_HERE/$LDAP_PROVIDER_ID/" ldap-group-config.json

./kcadm.sh create components -r master -f ldap-group-config.jsonadmin     

## Group mapping :
# 1. Get  LDAP provider ID
LDAP_PROVIDER_ID=$(./kcadm.sh get components -r my-realm \
  --query 'providerId=ldap' \
  --fields id \
  --format csv | tail -n +2)

## 2. Get the LDAP Group Mapper ID
# Each LDAP provider has a group-ldap-mapper. List them and save to var:

GROUP_MAPPER_ID=$(./kcadm.sh get components -r my-realm \
  --query "providerId=group-ldap-mapper&parentId=$LDAP_PROVIDER_ID" \
  --fields id \
  --format csv | tail -n +2 | cut -d, -f1)

## 3 Trigger group sync from LDAP
# To pull groups and their members from LDAP into Keycloak:
# This will: 
   - Import all LDAP groups (according to the mapper configuration).
   - Import group memberships (i.e., users automatically assigned to those groups).
./kcadm.sh create user-storage/$LDAP_PROVIDER_ID/sync -r my-realm \
  -s action=triggerFullSync

# For incremental sync instead or Updates Only:
./kcadm.sh create user-storage/$LDAP_PROVIDER_ID/sync -r my-realm \
  -s action=triggerChangedUsersSync

ldap-group-member.json template:
{
  "name": "ad-group-mapper",
  "providerId": "group-ldap-mapper",
  "providerType": "org.keycloak.storage.ldap.mappers.LDAPStorageMapper",
  "parentId": "LDAP_PROVIDER_ID_REPLACE_ME",
  "config": {
    "group.name.ldap.attribute": ["cn"],
    "group.object.classes": ["group"],
    "preserve.group.inheritance": ["false"],
    "ignore.missing.groups": ["false"],
    "membership.ldap.attribute": ["member"],
    "membership.attribute.type": ["DN"],
    "membership.user.ldap.attribute": ["distinguishedName"],
    "groups.dn": ["CN=Users,DC=example,DC=com"],
    "mode": ["READ_ONLY"],
    "user.roles.retrieve.strategy": ["LOAD_GROUPS_BY_MEMBER_ATTRIBUTE"],
    "mapped.group.attributes": ["description"],
    "drop.non.existing.groups.during.sync": ["true"]
  }
}

 # 1.  Get LDAP provider id
 LDAP_PROVIDER_ID=$(./kcadm.sh get components -r my-realm \
  --query 'providerId=ldap' --fields id --format csv | tail -n +2)
 # 2. place ID into  json template
 sed "s/LDAP_PROVIDER_ID_REPLACE_ME/$LDAP_PROVIDER_ID/" ldap-group-mapper.json > ldap-group-mapper-final.json

# 3. Create mapper: 
  ./kcadm.sh create components -r my-realm -f ldap-group-mapper-final.json
## Result:  groups in Keycloak -> LDAP groups created and users assigned as members.

### mapped.group.attributes field in the Keycloak LDAP Group Mapper tells Keycloak which AD group attributes we want to carry over and expose as Keycloak group attributes.

## For Active Directory (AD), we can map any LDAP attribute available on the AD group object.
1. attributes are available in AD groups, we can query them directly:

ldapsearch -H ldap://-ad-server -D "binduser@example.com" -w "password" \
-b "CN=Users,DC=example,DC=com" "(objectClass=group)" cn description mail managedBy
## List AD group attributes you can use (besides description):
Attribute Name	          Meaning
cn	                Common Name (group name itself).
distinguishedName	  Full DN of the group.
name	              Display name of the group.
sAMAccountName	    Legacy logon name of the group.
objectGUID	        Globally unique ID for the group.
objectSid	          Security identifier (SID) for the group.
mail	              Email address of the group.
memberOf	          Groups that this group is a member of (nested membership).
managedBy	          DistinguishedName of the user/group that manages this     group.
whenCreated	        Timestamp when the group was created.
whenChanged	        Timestamp of the last modification.
info	              General info field (sometimes used for notes).
telephoneNumber	    Telephone number, if set on the group object.
url	                Web URL associated with the group.

###  Inspecting mapper details
./kcadm.sh get components/${GROUP_MAPPER_ID} -r my-realm-dev

>> → Shows the configuration of that specific group mapper.

1. Updating mapped attributes (like mapped.group.attributes)

./kcadm.sh update components/${GROUP_MAPPER_ID} -r my-realm-dev -s 'config.mapped.group.attributes=["description","mail"]'

2. Deleting a group mapper

./kcadm.sh delete components/${GROUP_MAPPER_ID} -r my-realm-dev

### Testing or verifying configuration
### How to get the GROUP_MAPPER_ID:
  >> Run this to list all components of type group-ldap-mapper:

./kcadm.sh get components -r my-realm-dev \
  --query 'providerId=group-ldap-mapper' \
  --fields id,name,providerId \
  --format csv
### Sync
./kcadm.sh create user-storage/${LDAP_PROVIDER_ID}/sync -r my-realm-dev -s action=triggerFullSync

### Keycloak-only group membership via JSON:
  # Create a group if not exists
./kcadm.sh create groups -r my-realm-dev -s name=my-group

  # Get group ID
GROUP_ID=$(./kcadm.sh get groups -r my-realm-dev --fields id,name --format csv | grep my-group | cut -d, -f1)

  # Assign user to group (by JSON)
./kcadm.sh create users/<USER_ID>/groups/${GROUP_ID} -r my-realm-dev -s '{}'

### ========================
  - Configure the LDAP group mapper,
  - Trigger a sync, and
  - Verify users show up in the mapped groups

=====================================================
  Secure LDAP (LDAPS)
  LDAP group membership check
  Spring Boot version of this code
  JSON input/output API version
-----
- Mapper tells Keycloak: “map AD groups under OU=Groups,... and use member attribute to find users.”
- Sync pulls groups + memberships from AD into Keycloak.
- Script lists groups and shows which groups a user belongs to.
-------
# 4. Ensure group exists
GROUP_ID=$(./kcadm.sh get groups -r $REALM --query name=$GROUP_NAME --fields id --format csv | tail -n +2 | cut -d, -f1)
if [ -z "$GROUP_ID" ]; then
  echo "Group $GROUP_NAME not found. Creating..."
  GROUP_ID=$(./kcadm.sh create groups -r $REALM -s name=$GROUP_NAME -i)
fi

# 5. Check if user exists
USER_ID=$(./kcadm.sh get users -r $REALM -q username=$LOCAL_USER --fields id --format csv | tail -n +2 | cut -d, -f1)

if [ -z "$USER_ID" ]; then
  echo "User $LOCA*L_USER not found in Keycloak. Creating..."
  USER_ID=$(./kcadm.sh create users -r $REALM -s username=$LOCAL_USER -s enabled=true -s email=$LOCAL_EMAIL -i)
  # Optionally set password
  ./kcadm.sh set-password -r $REALM --userid $USER_ID --new-password 'Passw0rd!' --temporary
fi

# 6. Assign user to group
echo "Assigning $LOCAL_USER to group $GROUP_NAME..."
./kcadm.sh update users/$USER_ID/groups/$GROUP_ID -r $REALM -s realm=$REALM

# 7. Verify memberships
echo "Groups for $LOCAL_USER:"
./kcadm.sh get users/$USER_ID/groups -r $REALM

=================================
## Step 2: Loop through all users and map to groups
REALM="my-realm-dev"

# Example: Get all groups
GROUPS=$(./kcadm.sh get groups -r $REALM --fields id,name --format csv | tail -n +2)

# Example: Get all users
USERS=$(./kcadm.sh get users -r $REALM --fields id,username --format csv | tail -n +2)

# Loop through users and add to a group
while IFS=, read -r USER_ID USERNAME; do
  USER_ID=$(echo "$USER_ID" | tr -d '"')
  USERNAME=$(echo "$USERNAME" | tr -d '"')

  echo "Processing user $USERNAME ($USER_ID)"

  # Pick group by name (example: "dev-group")
  GROUP_ID=$(echo "$GROUPS" | grep "dev-group" | cut -d, -f1 | tr -d '"')

  if [ -n "$GROUP_ID" ]; then
    echo " -> Adding $USERNAME to group dev-group"
    ./kcadm.sh update users/$USER_ID/groups/$GROUP_ID -r $REALM -s realm=$REALM
  fi

done <<< "$USERS"

=============================================
### Step 3: Generalize (map multiple groups automatically)

If LDAP already has user–group memberships, Keycloak will sync them automatically if LDAP Group Mapperalready set up.
If not, we can drive it with a mapping file 
 - example:
  username,groupname
  alice,dev-group
  bob,qa-group
  carol,admin-group
## And process like:

while IFS=, read -r USERNAME GROUPNAME; do
  USER_ID=$(./kcadm.sh get users -r $REALM -q username=$USERNAME --fields id --format csv | tail -n +2 | tr -d '"')
  GROUP_ID=$(./kcadm.sh get groups -r $REALM --fields id,name --format csv | grep "$GROUPNAME" | cut -d, -f1 | tr -d '"')

  if [ -n "$USER_ID" ] && [ -n "$GROUP_ID" ]; then
    ./kcadm.sh update users/$USER_ID/groups/$GROUP_ID -r $REALM -s realm=$REALM
    echo "Mapped $USERNAME -> $GROUPNAME"
  fi
done < user-group-map.csv
------------------------------
----Input Users into groups------------
# Space-separated list of usernames (Keycloak usernames)
USERS=("alice" "bob" "charlie")

# Get Group IDs from group names
declare -A GROUP_IDS
for group in "${GROUPS[@]}"; do
  GROUP_ID=$(./kcadm.sh get groups -r $REALM --fields id,name | jq -r ".[] | select(.name==\"$group\") | .id")
  if [[ -n "$GROUP_ID" ]]; then
    GROUP_IDS[$group]=$GROUP_ID
  else
    echo " Group '$group' not found in realm '$REALM'"
  fi
done

# Get User IDs from usernames
1. from file
# Space-separated list of usernames (Keycloak usernames)
USERS=("alice" "bob" "charlie")

# Get Group IDs from group names
declare -A GROUP_IDS
for group in "${GROUPS[@]}"; do
  GROUP_ID=$(./kcadm.sh get groups -r $REALM --fields id,name | jq -r ".[] | select(.name==\"$group\") | .id")
  if [[ -n "$GROUP_ID" ]]; then
    GROUP_IDS[$group]=$GROUP_ID
  else
    echo " Group '$group' not found in realm '$REALM'"
  fi
done

# get users from file:
#!/bin/bash

# Read users from CSV into USERS array
USERS=()
while IFS=, read -r user; do
  # skip empty lines
  [[ -z "$user" ]] && continue
  USERS+=("$user")
done < users.csv

# Print to confirm
echo "Loaded users: ${USERS[@]}"

---------
# Get User IDs from usernames
declare -A USER_IDS
for user in "${USERS[@]}"; do
  USER_ID=$(./kcadm.sh get users -r $REALM -q username=$user --fields id | jq -r '.[0].id')
  if [[ -n "$USER_ID" && "$USER_ID" != "null" ]]; then
    USER_IDS[$user]=$USER_ID
  else
    echo " User '$user' not found in realm '$REALM'"
  fi
done


# Assign each user to each group
for user in "${!USER_IDS[@]}"; do
  for group in "${!GROUP_IDS[@]}"; do
    echo " Assigning user '$user' to group '$group'"
    # The command for assigning a user to a group is 'create' with -b '{}'  <- sends empty json => it is required.
    ./kcadm.sh create users/${USER_IDS[$user]}/groups/${GROUP_IDS[$group]} -r $REALM -s realm=$REALM -b '{}'
  done
done
## example:
USER_ID=$(./kcadm.sh get users -r myrealm -q username=jdoe --fields id --format csv --noquotes | tail -n 1)
GROUP_ID=$(./kcadm.sh get groups -r myrealm --fields id,name | jq -r '.[] | select(.name=="developers") | .id')

./kcadm.sh create users/$USER_ID/groups/$GROUP_ID -r myrealm -b '{}'
## test get user
./kcadm.sh get users -r $REALM -q username=jdoe --fields id
## test get group
./kcadm.sh get groups -r $REALM | jq -r '.[] | select(.name=="developers") | .id'

## Skip 2 values
#!/bin/bash
VALUES=("one" "two" "three" "four" "five")
for ((i=2; i<${#VALUES[@]}; i++)); do
    echo "Value: ${VALUES[$i]}"
done

-------------------------------
### LDAP groups are empty in Keycloak
 - Group Mapper is not configured with “Membership” properly
 - In Keycloak, go to:
    - User Federation → LDAP provider → Mappers → LDAP Group Mapper
Check:
    - Group Name LDAP attribute → usually cn
    - Group Object Classes → usually groupOfNames or posixGroup (depends on  AD/LDAP)
    - Membership LDAP Attribute → usually member or uniqueMember (Active Directory often uses member)
    - Membership Attribute Type → DN for AD, sometimes UID for OpenLDAP
    - User LDAP Attribute → usually dn
    - User DN vs. UID mismatch
    - AD groups often store members as distinguishedName (DN), e.g.

>>>>>>>>>>>>
Enable DEBUG logs for LDAP sync in standalone.xml:

<logger category="org.keycloak.storage.ldap">
  <level name="DEBUG"/>
</logger>
</logger>

=============================================================
== DB PostgreSQL=============================================
1. Local (Docker / Docker Compose)
  1.1. Create a docker/ compose/ deployment configuration:
  1.2. integrate SSL cert (Optional in local)
  1.3 Keycloak Connection 
2. Deployment to AKS (Azure Kubernetes Service)
  2.1. PostgreSQL (Azure Flexible Server / StatefulSet in AKS)
    postgres-deployment.yaml
  2.2. Keycloak Helm chart
  2.3. Expose Keycloak in AKS 
    kind: Ingress
  2.4  Integrate with SSL (Inject/ Vault/ Config ) 
3. Integrate AKS with Azure Key Vault 
  3.1. Create Requests
  3.2. Install Drivers for SSL
  3.3. Enable AKS Identity Mangement 
  3.4. Update Vault with Certs and secrets , Sync Key Vault secrets
  3.5. Assign AKS Identity permissions
  3.6. Update Config for CSI (Container Storage Int) with required drivers
  3.7. Deploy Keycloak with SSL connection


Deploy:
>>bash:
  kubectl apply -f postgres-deployment.yaml
>> helm
  helm repo add keycloak https://charts.bitnami.com/bitnami
  helm repo update

helm install keycloak keycloak/keycloak \
  --set auth.adminUser=admin \
  --set auth.adminPassword=admin \
  --set postgresql.enabled=false \
  --set externalDatabase.host=postgres \
  --set externalDatabase.user=keycloak \
  --set externalDatabase.password=keycloak \
  --set externalDatabase.database=keycloak

>> Step 3: Expose Keycloak in AKS
## If you’re using an Ingress + AGIC (Azure Application Gateway Ingress Controller):
- Apply ingress and map DNS to Application Gateway → AKS service.

>>yaml:
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: keycloak-ingress
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
spec:
  rules:
  - host: keycloak.mycompany.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: keycloak
            port:
              number: 80



-------------
>> yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
type: Opaque
data:
  POSTGRES_DB: a2V5Y2xvYWs=          # base64("keycloak")
  POSTGRES_USER: a2V5Y2xvYWs=        # base64("keycloak")
  POSTGRES_PASSWORD: a2V5Y2xvYWs=    # base64("keycloak")

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: "postgres"
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15
        ports:
        - containerPort: 5432
        envFrom:
        - secretRef:
            name: postgres-secret
        volumeMounts:
        - mountPath: /var/lib/postgresql/data
          name: postgres-data
  volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 5Gi

---
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  ports:
    - port: 5432
  clusterIP: None
  selector:
    app: postgres
===============================================
1. Why Infinispan with Keycloak
  - Keycloak uses Infinispan internally for caching:
    1. Authentication sessions
    2. User sessions
    3. Login failures
    4. Offline tokens
  2. By default, it runs in embedded mode (good for single-node dev).
  3. In AKS HA clusters, must run it in remote/distributed mode, pointing to an external Infinispan cluster.
  ### 2. Local Development Setup (Docker/Helm)
    -Run Infinispan locally
docker run -d --name infinispan -p 11222:11222 \
  -e USER="admin" -e PASS="password" \
  infinispan/server:14.0

b) Install Keycloak with Infinispan integration (Helm)
>> This config Keycloak to use remote Infinispan cache instead of embedded one.
>> By using Bitnami’s Keycloak Helm chart:

helm repo add bitnami https://charts.bitnami.com/bitnami
helm install keycloak bitnami/keycloak \
  --set auth.adminUser=admin \
  --set auth.adminPassword=adminpassword \
  --set cache.enabled=true \
  --set cache.stack=kubernetes \
  --set extraEnvVars[0].name=KC_CACHE \
  --set extraEnvVars[0].value=ispn \
  --set extraEnvVars[1].name=KC_CACHE_REMOTE_HOST \
  --set extraEnvVars[1].value=localhost \
  --set extraEnvVars[2].name=KC_CACHE_REMOTE_PORT \
  --set extraEnvVars[2].value=11222 \
  --set extraEnvVars[3].name=KC_CACHE_REMOTE_USERNAME \
  --set extraEnvVars[3].value=admin \
  --set extraEnvVars[4].name=KC_CACHE_REMOTE_PASSWORD \
  --set extraEnvVars[4].value=password

3. AKS (Azure Kubernetes Service) Setup
a) Deploy Infinispan cluster on AKS
>> create: StatefulSet for Infinispan cluster
          Expose port 11222
          Secret with username/password for clients
>> bash:          
helm repo add infinispan https://infinispan.github.io/infinispan-helm-charts
helm install infinispan infinispan/infinispan \
  --set security.endpointAuthentication=true \
  --set security.endpointSecretName=infinispan-auth
------------
b) Deploy Keycloak pointing to Infinispan
helm install keycloak bitnami/keycloak \
  --set auth.adminUser=admin \
  --set auth.adminPassword=adminpassword \
  --set cache.enabled=true \
  --set cache.stack=kubernetes \
  --set extraEnvVars[0].name=KC_CACHE \
  --set extraEnvVars[0].value=ispn \
  --set extraEnvVars[1].name=KC_CACHE_REMOTE_HOST \
  --set extraEnvVars[1].value=infinispan.default.svc.cluster.local \
  --set extraEnvVars[2].name=KC_CACHE_REMOTE_PORT \
  --set extraEnvVars[2].value=11222 \
  --set extraEnvVars[3].name=KC_CACHE_REMOTE_USERNAME \
  --set extraEnvVars[3].value=$(kubectl get secret infinispan-auth -o jsonpath='{.data.identities\.yaml}' | base64 -d | grep username | awk '{print $2}') \
  --set extraEnvVars[4].name=KC_CACHE_REMOTE_PASSWORD \
  --set extraEnvVars[4].value=$(kubectl get secret infinispan-auth -o jsonpath='{.data.identities\.yaml}' | base

4. Verification
  - Keycloak logs should show:
    Using remote Infinispan cache...
    Connected to Infinispan cluster: infinispan@11222
  - Test by scaling Keycloak:
>> bash: Keycloak already bundles Infinispan. Just start Keycloak:
kubectl scale deployment keycloak --replicas=3
docker run -p 8080:8080 quay.io/keycloak/keycloak:24.0 start-dev

>>Local:
docker run -it -p 11222:11222 \
  -e USER=admin -e PASS=admin \
  quay.io/infinispan/server:14.0

### Testing Option B: External Infinispan (Standalone)
 - Run Infinispan locally:

docker run -it -p 11222:11222 \
  -e USER=admin -e PASS=admin \
  quay.io/infinispan/server:14.0

## Configure Keycloak to use external Infinispan by editing conf/cache-ispn.xml:

<infinispan>
  <remote-cache-container name="external">
    <remote-server host="localhost" port="11222"/>
    <security>
      <authentication>
        <username>admin</username>
        <password>admin</password>
      </authentication>
    </security>
  </remote-cache-container>
</infinispan>


## Start Keycloak with external cache:
  bin/kc.sh start --cache=ispn --cache-config=conf/cache-ispn.xml
===================================================================

3. AKS Setup (Helm)
## Step 1: Deploy Infinispan to AKS

Use the Infinispan Helm chart:

helm repo add infinispan https://infinispan.github.io/infinispan-helm-charts
helm install infinispan infinispan/infinispan --set security.auth.enabled=true

## Step 2: Deploy Keycloak with Helm
helm repo add codecentric https://codecentric.github.io/helm-charts
helm install keycloak codecentric/keycloak \
  --set keycloak.replicas=3 \
  --set keycloak.extraEnv[0].name=KEYCLOAK_CACHE \
  --set keycloak.extraEnv[0].value=ispn \
  --set keycloak.extraEnv[1].name=KEYCLOAK_CACHE_CONFIG_FILE \
  --set keycloak.extraEnv[1].value=/opt/keycloak/conf/cache-ispn.xml

Step 3: Configure Keycloak to Point to Infinispan

Create a cache-ispn.xml ConfigMap:

<infinispan>
  <remote-cache-container name="external">
    <remote-server host="infinispan.default.svc.cluster.local" port="11222"/>
    <security>
      <authentication>
        <username>developer</username>
        <password>password</password>
      </authentication>
    </security>
  </remote-cache-container>
</infinispan>


Mount this config to Keycloak Pods:

extraVolumes:
  - name: cache-config
    configMap:
      name: cache-ispn

extraVolumeMounts:
  - name: cache-config
    mountPath: /opt/keycloak/conf/cache-ispn.xml
    subPath: cache-ispn.xml

🔹 4. Verification
  # Check if Keycloak connects to Infinispan:
    kubectl logs keycloak-0 | grep infinispan
  # Verify cache is distributed across pods:
    kubectl exec -it infinispan-0 -- ./bin/cli.sh describe caches
# AKS → External Infinispan StatefulSet, HA-ready Keycloak pods with shared cache
------------------------------------------------
###### full Helm values.yaml (with Infinispan + Keycloak pre-integrated)
🔹 1. Local Setup (Docker / Docker Compose)
Step 1: Run Infinispan Locally
# docker-compose.yml
version: '3.8'
services:
  infinispan:
    image: infinispan/server:14.0
    environment:
      USER: admin
      PASS: password
    ports:
      - "11222:11222"

  keycloak:
    image: quay.io/keycloak/keycloak:24.0
    command:
      - start
      - --cache=ispn
      - --cache-stack=kubernetes
    environment:
      KC_CACHE: ispn
      KC_CACHE_STACK: tcp
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres:5432/keycloak
      KC_DB_USERNAME: keycloak
      KC_DB_PASSWORD: password
      KC_HOSTNAME: localhost
      KC_LOG_LEVEL: INFO
      KC_CACHE_REMOTE_HOST: infinispan
      KC_CACHE_REMOTE_PORT: 11222
      KC_CACHE_REMOTE_USERNAME: admin
      KC_CACHE_REMOTE_PASSWORD: password
    ports:
      - "8080:8080"
    depends_on:
      - infinispan
      - postgres

  postgres:
    image: postgres:14
    environment:
      POSTGRES_USER: keycloak
      POSTGRES_PASSWORD: password
      POSTGRES_DB: keycloak
    ports:
      - "5432:5432"


Example infinispan.xml (custom config to point Keycloak to remote Infinispan):

<infinispan>
  <cache-container name="keycloak">
    <transport stack="tcp"/>
    <remote-store xmlns="urn:infinispan:config:store:remote:14.0">
      <remote-server host="infinispan" port="11222"/>
      <security>
        <authentication>
          <username>admin</username>
          <password>password</password>
        </authentication>
      </security>
    </remote-store>
  </cache-container>
</infinispan>

🔹 2. AKS Setup (Helm) Helm Chart (Local Minikube or Docker Desktop)
- Install Infinispan Operator:
Step 1: Deploy Infinispan (Helm Chart)
helm repo add infinispan https://infinispan.github.io/infinispan-helm-charts
helm install my-infinispan infinispan/infinispan \
  --set security.auth.username=admin \
  --set security.auth.password=password \
  --namespace keycloak
## or Infinispan Setup on AKS (Helm) with Infinispan cache enabled:
helm repo add infinispan https://infinispan.github.io/infinispan-helm-charts/
helm repo update
helm install infinispan infinispan/infinispan --namespace keycloak --create-namespace

## Step 2: Deploy Keycloak with Infinispan Cache
  Using the Bitnami Keycloak Helm chart:
  Expose service (LoadBalancer or ClusterIP depending on  setup):
>>bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

## Create Custom values for Keycloak
auth:
  adminUser: admin
  adminPassword: admin

postgresql:
  enabled: true
  auth:
    username: keycloak
    password: password
    database: keycloak

extraEnvVars:
  - name: KC_CACHE
    value: ispn
  - name: KC_CACHE_STACK
    value: kubernetes
  - name: KC_CACHE_REMOTE_HOST
    value: infinispan.keycloak.svc.cluster.local
  - name: KC_CACHE_REMOTE_PORT
    value: "11222"
  - name: KC_CACHE_REMOTE_USERNAME
    value: developer
  - name: KC_CACHE_REMOTE_PASSWORD
    valueFrom:
      secretKeyRef:
        name: infinispan-generated-secret
        key: password


------
kubectl expose statefulset my-infinispan \
  --name=my-infinispan-service \
  --port=11222 \
  --target-port=11222 \
  --namespace keycloak

Step 2: Deploy Keycloak with Helm
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install keycloak bitnami/keycloak \
  --set auth.adminUser=admin \
  --set auth.adminPassword=adminpassword \
  --set externalDatabase.host=my-postgres.keycloak.svc.cluster.local \
  --set externalDatabase.user=keycloak \
  --set externalDatabase.password=keycloak \
  --set externalDatabase.database=keycloak \
  --set cache.enabled=true \
  --set extraEnv[0].name=KC_CACHE \
  --set extraEnv[0].value=ispn \
  --set extraEnv[1].name=KC_CACHE_CONFIG_FILE \
  --set extraEnv[1].value=/opt/bitnami/keycloak/conf/infinispan.xml


Then mount infinispan.xml via a ConfigMap:

kubectl create configmap keycloak-infinispan-conf \
  --from-file=infinispan.xml \
  -n keycloak


Patch the Keycloak deployment to mount it:

volumeMounts:
  - name: infinispan-conf
    mountPath: /opt/bitnami/keycloak/conf/infinispan.xml
    subPath: infinispan.xml

volumes:
  - name: infinispan-conf
    configMap:
      name: keycloak-infinispan-conf

#### 🔹 3. Verify Integration
## Check Keycloak logs:
>> bash
  kubectl logs -f deploy/keycloak -n keycloak


## Test:
 - logs showing remote Infinispan connection.
 - Log in to Keycloak Admin Console → Monitor cluster nodes (show Infinispan caches).
  - show Keycloak caches:
    Infinispan dashboard (http://<infinispan-host>:11222) 

### 4. Verify Infinispan Connection
  1. Local: open http://localhost:11222/console
  2. Thank youAKS: port-forward to Infinispan service:
    kubectl port-forward svc/infinispan 11222:11222 -n keycloak

====================================================================

### Option 3. => AKS Deployment with Helm
Step 1: Deploy Infinispan Operator
helm install infinispan-operator infinispan/infinispan-operator


## Create an Infinispan cluster in AKS:

apiVersion: infinispan.org/v1
kind: Infinispan
metadata:
  name: kc-infinispan
spec:
  replicas: 2
  service:
    type: DataGrid
  security:
    endpointSecretName: kc-infinispan-secret

## Step 2: Expose Secret for Keycloak
  Get username/password from secret:
kubectl get secret kc-infinispan-secret -o yaml

## Step 3: Deploy Keycloak Helm Chart (Codecentric or Bitnami)
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install keycloak bitnami/keycloak \
  --set cache.enabled=true \
  --set cache.stack=tcp \
  --set cache.remoteServers=kc-infinispan:11222 \
  --set cache.username=admin \
  --set cache.password=password

4. Validation

# Check Keycloak logs:
kubectl logs -f keycloak-0

# Expected:
  INFO  [org.infinispan] ISPN000621: Connected to remote Infinispan server kc-infinispan:11222

# Check cluster view in Infinispan:

kubectl port-forward svc/kc-infinispan 11222:11222
curl -u admin:password http://localhost:11222/rest/v2/cache-managers/default/health/status
  Should return HEALTHY.postgresrecycle
**
*  
===================================================================
5. Production Notes
  Use TLS between Keycloak and Infinispan (enable with --set security.endpointEncryption=true).
  Store Infinispan creds in Kubernetes Secrets (instead of plaintext).
  If you run multiple Keycloak instances, ensure:
    KC_CACHE=ispn
    KC_CACHE_STACK=kubernetes
  Configure readiness/liveness probes so Keycloak only starts after Infinispan is reachable.

=============================================================================
🔹 1. What "App Context" Usually Means in AKS
In AKS (or Kubernetes in general), application context can refer to:
   - Kubernetes Context: The kubectl context that tells which AKS cluster/namespace you’re operating in.

  - Application Deployment Context: The runtime environment and configuration that  app (e.g., Keycloak) runs with.

  - Helm Release Context: Values and overrides you pass to Helm to customize deployment.
=============

🔹 2. Kubernetes Context in AKS
  If you have multiple clusters, kubectl must know which AKS cluster to talk to.
Check  contexts:
    kubectl config get-contexts
Switch context:
    kubectl config use-context <aks-cluster-name>

If you don’t have the AKS context locally, fetch it:
  az aks get-credentials -g <resource-group> -n <aks-cluster-name>
=============

🔹 3. Application Context for Keycloak in AKS
  When you deploy Keycloak in AKS (via Helm chart or custom manifests), you define context through:

## Namespace
  >> kubectl create namespace keycloak

## Helm release
Example:

helm install keycloak codecentric/keycloakx \
  -n keycloak \
  -f values.yaml


## ConfigMaps & Secrets
  - Store DB URLs, Infinispan configs, LDAP configs, etc.
>>
kubectl create secret generic keycloak-db-secret \
  --from-literal=DB_USER=kcuser \
  --from-literal=DB_PASSWORD=kcpass


## Environment Variables (via Helm values or YAML)

extraEnv: 
  - name: KC_DB_URL
    value: jdbc:postgresql://postgres.keycloak.svc.cluster.local:5432/keycloak
  - name: KC_CACHE
    value: ispn

## This is an application runtime context in AKS.
============

🔹 4. Integration Contexts in AKS
    If running Keycloak + Infinispan + LDAP in AKS:

Keycloak needs service DNS for Infinispan:
ispn-0.ispn.keycloak.svc.cluster.local

Keycloak needs DNS for LDAP or AD (usually external, so via ServiceEntry or ClusterIP).

Secure them with TLS secrets stored in Kubernetes.
============

🔹 5. Full "App Context" in AKS for Keycloak
    1. Namespace keycloak
    2. Keycloak configured with Infinispan (distributed cache)
    3. PostgreSQL DB for Keycloak
    4. LDAP federation integration (Active Directory or OpenLDAP)

### application context includes:
  Namespace keycloak
  Helm release keycloak
  DB + cache configs
  Ingress hostname

✅ AKS app context = that define how  app runs.
    = cluster/namespace 
    + Helm values 
    + secrets/config 

----------------------------------------------------------
values.yaml (Helm for Keycloak):

# replicas: 2
# Deploy Keycloak with Infinispan and LDAP in AKS

replicaCount: 2
namespace: keycloak

image:
  repository: quay.io/keycloak/keycloak
  tag: 24.0.3
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 8080

ingress:
  enabled: true
  hostname: keycloak.example.com
  annotations:
    kubernetes.io/ingress.class: nginx
  tls:
    - hosts:
        - keycloak.example.com
      secretName: keycloak-tls

extraEnv:
  # Database
  - name: KC_DB
    value: postgres
  - name: KC_DB_URL
    value: jdbc:postgresql://postgresql.keycloak.svc.cluster.local:5432/keycloak
  - name: KC_DB_USERNAME
    valueFrom:
      secretKeyRef:
        name: keycloak-db-secret
        key: DB_USER
  - name: KC_DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: keycloak-db-secret
        key: DB_PASSWORD

  # Infinispan Distributed Cache
  - name: KC_CACHE
    value: ispn
  - name: KC_CACHE_STACK
    value: kubernetes
  - name: KC_CACHE_CONFIG_FILE
    value: cache-ispn.xml

  # LDAP Federation
  - name: LDAP_CONNECTION_URL
    value: ldaps://ldap.keycloak.svc.cluster.local:636
  - name: LDAP_BIND_DN
    valueFrom:
      secretKeyRef:
        name: ldap-secret
        key: binddn
  - name: LDAP_BIND_CREDENTIALS
    valueFrom:
      secretKeyRef:
        name: ldap-secret
        key: password
  - name: LDAP_USERS_DN
    value: "ou=Users,dc=example,dc=com"
  - name: LDAP_GROUPS_DN
    value: "ou=Groups,dc=example,dc=com"

volumes:
  - name: keycloak-truststore
    secret:
      secretName: keycloak-truststore
volumeMounts:
  - mountPath: /opt/keycloak/conf/truststore
    name: keycloak-truststore
    readOnly: true

postgresql:
  enabled: true
  auth:
    username: kcuser
    password: kcpassword
    database: keycloak

ispn:
  enabled: true
  replicas: 2
  service:
    name: ispn
    port: 7800

 
=====================================================
============= Secrets for DB + LDAP + TLS ===========

🗂️ Supporting Secrets (create before Helm install)
>>🔐 DB Secret 
kubectl create secret generic keycloak-db-secret -n keycloak \
  --from-literal=DB_USER=kcuser \
  --from-literal=DB_PASSWORD=kcpassword
🔐 LDAP Secret
kubectl create secret generic ldap-secret -n keycloak \
  --from-literal=binddn="cn=admin,dc=example,dc=com" \
  --from-literal=password="ldappassword"

🔐 Truststore Secret
kubectl create secret generic keycloak-truststore -n keycloak \
  --from-file=truststore.jks
======================================================
### Deploy

>> kubectl create namespace keycloak
>> helm repo add keycloak https://charts.bitnami.com/bitnami
>> helm install keycloak keycloak/keycloak -n keycloak -f values.yaml
# Create Postgres on AKS with Helm:
>> helm install keycloak-db bitnami/postgresql -n keycloak \
  --set auth.username=kcuser,auth.password=kcpassword,auth.database=keycloak
# Store credentials in a secret:
>> kubectl create secret generic keycloak-db-secret -n keycloak \
  --from-literal=DB_USER=kcuser \
  --from-literal=DB_PASSWORD=kcpassword

=======================================================
## HA (High Availability for Keycloak)
steps + configuration to run Keycloak with 
      - multiple pods, 
      - shared state  
      - stable DB/cache in AKS.
🔹 1. Prerequisites
    - AKS cluster created (az aks create …)
    - Ingress controller (e.g., NGINX Ingress or Azure Application Gateway Ingress Controller)
    - External database (PostgreSQL, Yugabyte, or Azure Database for PostgreSQL)
    - Shared distributed cache (Infinispan or JGroups/Kubernetes stack)
    - TLS certificates (via Cert-Manager or manual secret)
✅ Summary
  For HA in AKS:
    - Use Postgres/Yugabyte (shared DB)
    - Use Infinispan or JGroups for caching
    - Run 2–3 Keycloak pods minimum
    - Enable Ingress with TLS
    - Configure readiness/liveness probes
    - Use HPA for scaling    
    
🔹 2. Namespace
    >> kubectl create namespace keycloak
🔹 3. Database (PostgreSQL recommended)  Keycloak cannot share state without a proper DB. Can be created with Helm:
  >> helm repo add bitnami https://charts.bitnami.com/bitnami
  >> helm install keycloak-db bitnami/postgresql -n keycloak \
    --set auth.username=kcuser,auth.password=kcpassword,auth.database=keycloak

🔹4. Store credentials in a secret:
>> kubectl create secret generic keycloak-db-secret -n keycloak \
  --from-literal=DB_USER=kcuser \
  --from-literal=DB_PASSWORD=kcpassword    
🔹 4. Caching for Multi-Pod
  Keycloak needs Infinispan distributed cache for session clustering.
  Two options:
    1. Kubernetes JGroups Stack (simpler, no external Infinispan cluster)
    2. Dedicated Infinispan cluster (preferred for large setups)
Example config for Kubernetes JGroups Stack:

extraEnv:
  - name: KC_CACHE
    value: ispn
  - name: KC_CACHE_STACK
    value: kubernetes
🔹 5. Keycloak Deployment (Helm values.yaml)

Here’s a multi-pod ready override:

replicaCount: 3

image:
  repository: quay.io/keycloak/keycloak
  tag: 24.0.3
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 8080

ingress:
  enabled: true
  hostname: keycloak.mydomain.com
  annotations:
    kubernetes.io/ingress.class: nginx
  tls:
    - hosts:
        - keycloak.mydomain.com
      secretName: keycloak-tls

extraEnv:
  - name: KC_DB
    value: postgres
  - name: KC_DB_URL
    value: jdbc:postgresql://keycloak-db-postgresql.keycloak.svc.cluster.local:5432/keycloak
  - name: KC_DB_USERNAME
    valueFrom:
      secretKeyRef:
        name: keycloak-db-secret
        key: DB_USER
  - name: KC_DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: keycloak-db-secret
        key: DB_PASSWORD
  - name: KC_CACHE
    value: ispn
  - name: KC_CACHE_STACK
    value: kubernetes
  - name: KC_HEALTH_ENABLED
    value: "true"
  - name: KC_METRICS_ENABLED
    value: "true"
  - name: KC_PROXY
    value: edge

resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 1
    memory: 2Gi

🔹 6. Scaling Keycloak Pods

Deploy Keycloak with Helm:

helm repo add keycloak https://charts.bitnami.com/bitnami
helm install keycloak keycloak/keycloak -n keycloak -f values.yaml


Scale pods:

kubectl scale deployment keycloak --replicas=3 -n keycloak

🔹 7. Health Checks (Important for HA)

Keycloak exposes health endpoints:

livenessProbe:
  httpGet:
    path: /health/live
    port: http
readinessProbe:
  httpGet:
    path: /health/ready
    port: http


These ensure rolling updates & scaling are safe.

🔹 8. Ingress Controller

Expose Keycloak securely:

ingress:
  enabled: true
  hostname: keycloak.mydomain.com
  tls:
    - secretName: keycloak-tls
      hosts:
        - keycloak.mydomain.com


If using Azure Application Gateway Ingress Controller, set:

annotations:
  kubernetes.io/ingress.class: azure/application-gateway

🔹 9. TLS / Certificates

Either:

Use Cert-Manager (ClusterIssuer with Let’s Encrypt)

Or manually upload certs:

kubectl create secret tls keycloak-tls --cert=cert.pem --key=key.pem -n keycloak

🔹 10. Horizontal Autoscaling (Optional)

Enable HPA for Keycloak:

kubectl autoscale deployment keycloak \
  --cpu-percent=80 --min=3 --max=6 -n keycloak


====================================================
Keycloak HA in AKS — this will include:
  - Namespace
  - Secrets (DB credentials, TLS)
  - PostgreSQL StatefulSet (optional, for demo only — in production use Azure DB for PostgreSQL)
  - Keycloak Deployment with 3 replicas
  - Service (ClusterIP + optional headless)
  - Ingress with TLS

🗂️ keycloak-ha.yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: keycloak
---
# 🔐 DB Secret
apiVersion: v1
kind: Secret
metadata:
  name: keycloak-db-secret
  namespace: keycloak
type: Opaque
stringData:
  DB_USER: kcuser
  DB_PASSWORD: kcpassword
---
# 🔐 TLS Secret (replace with your certs or use cert-manager)
apiVersion: v1
kind: Secret
metadata:
  name: keycloak-tls
  namespace: keycloak
type: kubernetes.io/tls
data:
  tls.crt: BASE64_ENCODED_CERT
  tls.key: BASE64_ENCODED_KEY
---
# 🗄️ PostgreSQL (demo — replace with Azure Postgres in prod)
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: keycloak-db
  namespace: keycloak
spec:
  serviceName: keycloak-db
  replicas: 1
  selector:
    matchLabels:
      app: keycloak-db
  template:
    metadata:
      labels:
        app: keycloak-db
    spec:
      containers:
      - name: postgres
        image: postgres:15
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: keycloak
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: keycloak-db-secret
              key: DB_USER
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: keycloak-db-secret
              key: DB_PASSWORD
        volumeMounts:
        - mountPath: /var/lib/postgresql/data
          name: data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
---
apiVersion: v1
kind: Service
metadata:
  name: keycloak-db
  namespace: keycloak
spec:
  type: ClusterIP
  ports:
    - port: 5432
  selector:
    app: keycloak-db
---
### Keycloak Deployment

apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak
  namespace: keycloak
spec:
  replicas: 3
  selector:
    matchLabels:
      app: keycloak
  template:
    metadata:
      labels:
        app: keycloak
    spec:
      containers:
      - name: keycloak
        image: quay.io/keycloak/keycloak:24.0.3
        args: ["start"]
        ports:
        - containerPort: 8080
        env:
        - name: KC_DB
          value: postgres
        - name: KC_DB_URL
          value: jdbc:postgresql://keycloak-db.keycloak.svc.cluster.local:5432/keycloak
        - name: KC_DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: keycloak-db-secret
              key: DB_USER
        - name: KC_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: keycloak-db-secret
              key: DB_PASSWORD
        - name: KC_PROXY
          value: edge
        - name: KC_HOSTNAME
          value: keycloak.example.com
        - name: KC_CACHE
          value: ispn
        - name: KC_CACHE_STACK
          value: kubernetes
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
          initialDelaySeconds: 20
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
---
#  Keycloak Service
apiVersion: v1
kind: Service
metadata:
  name: keycloak
  namespace: keycloak
spec:
  type: ClusterIP
  ports:
    - port: 8080
      targetPort: 8080
  selector:
    app: keycloak
---
# 🌍 Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: keycloak
  namespace: keycloak
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  tls:
  - hosts:
      - keycloak.example.com
    secretName: keycloak-tls
  rules:
  - host: keycloak.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: keycloak
            port:
              number: 8080
============================
🔹 Deploy in AKS
>> kubectl apply -f keycloak-ha.yaml

🔹 Verify
NOdes: (if shows then config is correct)
  kubectl get nodes
Pods:
>>  kubectl get pods -n keycloak

Services:
>>  kubectl get svc -n keycloak

Ingress:
>>  kubectl get ingress -n keycloak

========================================= 
Summary:
✅ This will give:
  - 3 Keycloak pods in HA mode
  - Postgres running in AKS (replace with Azure PaaS DB in production)
  - Ingress with TLS (replace certs or integrate cert-manager)
  - Cluster-aware cache (Infinispan via JGroups Kubernetes stack)

=====================================================
HA High Avaliability for Keycloak!
=====================================================
1️⃣ Key Considerations for Keycloak HA
  - Stateless pods: Keycloak itself should be stateless → use database-backed persistence (PostgreSQL, YugabyteDB, etc.).
  - Infinispan distributed cache: Required for multi-node session clustering.
  - Multi-zone: Use Kubernetes PodAntiAffinity + topology spread constraints to spread pods across AZs.
  - Ingress: Load balancer (NGINX, Traefik, Azure AGIC, etc.) for external access.
  - Secrets: TLS certificates + DB credentials in Kubernetes Secrets.

2️⃣ High Availability Deployment (5 Pods, Multi-zone)
## 🔹 keycloak-deployment.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: keycloak
  namespace: keycloak
labels:
  app: keycloak
spec:
  replicas: 5
  selector:
    matchLabels:
      app: keycloak
  serviceName: keycloak-headless
  template:
    metadata:
      labels:
        app: keycloak
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: app
                    operator: In
                    values:
                      - keycloak
              topologyKey: "topology.kubernetes.io/zone"
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: keycloak
      containers:
      - name: keycloak
        image: quay.io/keycloak/keycloak:24.0.3
        args:
          - "start"
          - "--optimized"
        env:
        - name: KC_DB
          value: postgres
        - name: KC_DB_URL
          valueFrom:
            secretKeyRef:
              name: keycloak-db-secret
              key: jdbc-url
        - name: KC_DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: keycloak-db-secret
              key: username
        - name: KC_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: keycloak-db-secret
              key: password
        - name: KC_CACHE
          value: ispn
        - name: KC_CACHE_STACK
          value: kubernetes
        - name: KC_HOSTNAME_STRICT
          value: "false"
        - name: JAVA_OPTS_APPEND
          value: "-Djgroups.dns.query=keycloak-headless.keycloak.svc.cluster.local"
        ports:
        - containerPort: 8080
        - containerPort: 8443
---
apiVersion: v1
kind: Service
metadata:
  name: keycloak
  namespace: keycloak
spec:
  type: ClusterIP
  ports:
  - name: http
    port: 8080
  - name: https
    port: 8443
  selector:
    app: keycloak
---
apiVersion: v1
kind: Service
metadata:
  name: keycloak-headless
  namespace: keycloak
spec:
  clusterIP: None
  selector:
    app: keycloak
  ports:
  - port: 7800
    name: jgroups


========================
## 🔹 ingress.yaml (multi-zone LB entrypoint)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: keycloak
  namespace: keycloak
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  tls:
  - hosts:
    - keycloak.example.com
    secretName: keycloak-tls
  rules:
  - host: keycloak.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: keycloak
            port:
              number: 8080

## 3️⃣ Database Secret (Postgres / YugabyteDB)
apiVersion: v1
kind: Secret
metadata:
  name: keycloak-db-secret
  namespace: keycloak
type: Opaque
stringData:
  jdbc-url: "jdbc:postgresql://dbhost:5432/keycloak"
  username: "..."
  password: "..."

====================================================
====== MILTI AZ with Helms Charts ==================
## 🔹 values-ha.yaml (override file)
replicaCount: 5

auth:
  adminUser: admin
  adminPassword: admin123

proxy: edge
httpRelativePath: /

tls:
  enabled: true
  existingSecret: keycloak-tls

cache:
  enabled: true
  stack: kubernetes

service:
  type: ClusterIP
  ports:
    http: 8080
    https: 8443

extraEnvVars:
  - name: KC_CACHE
    value: "ispn"
  - name: KC_CACHE_STACK
    value: "kubernetes"
  - name: JAVA_OPTS_APPEND
    value: "-Djgroups.dns.query=keycloak-headless.keycloak.svc.cluster.local"
  - name: KC_HOSTNAME_STRICT
    value: "false"
# get secret
extraEnvVarsSecret: pgsql-db-secret

persistence:
  enabled: false

externalDatabase:
  enabled: true
  host: remote-postgres.example.com
  port: 5432
  user: keycloakuser
  existingSecret: pgsql-db-secret
  existingSecretPasswordKey: KC_DB_PASSWORD
  database: keycloak

podAntiAffinityPreset: hard
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: keycloak

resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 2
    memory: 4Gi


topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: keycloak

resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 2
    memory: 4Gi

ingress:
  enabled: true
  ingressClassName: nginx
  hostname: keycloak.example.com
  tls: true
  extraTls:
    - hosts:
        - keycloak.example.com
      secretName: keycloak-tls
=====================================================

## 🔹Deploy by Helm Chars:
1. Add the Bitnami repo (if not added):
>>  helm repo add bitnami https://charts.bitnami.com/bitnami
>>  helm repo update
2. Deploy Keycloak HA:
>> helm install keycloak bitnami/keycloak -n keycloak --create-namespace -f values-ha.yaml
3. Verify pods are spread across zones:
>> kubectl get pods -n keycloak -o wide

===========================
🔹 Step 1: Create the Secret (if not already created)
apiVersion: v1
kind: Secret
metadata:
  name: pgsql-db-secret
  namespace: keycloak
type: Opaque
stringData:
  KC_DB_PASSWORD: "keycloak"
---------------
## Apply it:
  kubectl apply -f pgsql-db-secret.yaml

==================================================================
## Test DB Connect by using yaml below:
1. kubectl apply -f postgres-connection-test.yaml
2. kubectl logs job/postgres-connection-test
-------------
>> yaml: postgres-connection-test.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: postgres-connection-test
spec:
  template:
    spec:
      containers:
        - name: psql
          image: postgres:15
          command: ["sh", "-c"]
          args:
            - >
              echo "Testing connection to Postgres...";
              PGPASSWORD=$POSTGRES_PASSWORD
              psql -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT NOW();"
          env:
            - name: POSTGRES_HOST
              value: "my-postgres.postgres.database.azure.com"
            - name: POSTGRES_PORT
              value: "5432"
            - name: POSTGRES_DB
              value: "keycloakdb"
            - name: POSTGRES_USER
              value: "keycloakuser"
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: pgsql-db-secret
                  key: password
      restartPolicy: Never
  backoffLimit: 1
-------------------  
---------- deployment keycloak with external DB ----------------------
----------------
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak
  labels:
    app: keycloak
spec:
  replicas: 2
  selector:
    matchLabels:
      app: keycloak
  template:
    metadata:
      labels:
        app: keycloak
    spec:
      containers:
        - name: keycloak
          image: quay.io/keycloak/keycloak:24.0.3
          args: ["start"]
          ports:
            - name: http
              containerPort: 8080
          env:
            - name: KC_DB
              value: postgres
            - name: KC_DB_URL
              value: "jdbc:postgresql://my-external-postgres.example.com:5432/keycloakdb"
            - name: KC_DB_USERNAME
              value: "keycloakuser"
            - name: KC_DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: pgsql-db-secret
                  key: password
            - name: KC_HOSTNAME
              value: "keycloak.mydomain.com"
          readinessProbe:
            httpGet:
              path: /realms/master
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
-----
--service ----------
apiVersion: v1
kind: Service
metadata:
  name: keycloak
spec:
  type: ClusterIP
  selector:
    app: keycloak
  ports:
    - name: http
      port: 80
      targetPort: 8080


### Secret (for DB password)
apiVersion: v1
kind: Secret
metadata:
  name: pgsql-db-secret
type: Opaque
data:
  password: <base64-encoded-password>
----------------
👉 Replace password with base64:
>> bash:
  echo -n 'mypassword' | base64



==================================================================
HPA Integration:
## Key Considerations
  1. Sticky Sessions: If Keycloak is behind an Ingress + Load Balancer, configure sticky sessions or Infinispan cache for session clustering.
  2. External DB: Scaling Keycloak requires externalizing Postgres (don’t run DB inside same pod).
  3. Infinispan / JDBC Cache: For real HA, configure Keycloak with Infinispan (replicated cache) or jdbc-ping discovery in AKS.
  4. Multi-Zone: If AKS spans zones, make sure to run podAntiAffinity to spread Keycloak pods.

### FOR HPA (Horizontal POD Autoscaler)


kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

## validate:
kubectl get apiservices | grep metrics

### 2. Deployment with Resource Requests & Limits
-- HPA works only if you define CPU/memory requests/limits.
>> sample Keycloak Deployment snippet:

apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak
  namespace: keycloak
spec:
  replicas: 2
  selector:
    matchLabels:
      app: keycloak
  template:
    metadata:
      labels:
        app: keycloak
    spec:
      containers:
      - name: keycloak
        image: quay.io/keycloak/keycloak:25.0.0
        args: ["start"]   # or start --optimized
        env:
          - name: KC_DB
            value: postgres
          - name: KC_DB_URL
            value: jdbc:postgresql://postgres-svc:5432/keycloakdb
          - name: KC_DB_USERNAME
            valueFrom:
              secretKeyRef:
                name: pgsql-db-secret
                key: username
          - name: KC_DB_PASSWORD
            valueFrom:
              secretKeyRef:
                name: pgsql-db-secret
                key: password
        ports:
          - containerPort: 8080
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
          limits:
            cpu: "1"
            memory: "2Gi"

============
## 3. Create the HPA
>> Example: scale between 2 and 5 pods if CPU > 70%.
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: keycloak-hpa
  namespace: keycloak
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: keycloak
  minReplicas: 2
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70

##  Apply HPA:
kubectl apply -f keycloak-hpa.yaml
## Verify Scaling:
kubectl get hpa -n keycloak

## Test -> Force Load Test:
kubectl run -i --tty load-generator --rm \
  --image=busybox:1.28 \
  -- /bin/sh -c "while true; do wget -q -O- http://keycloak:8080; done"
## Validate PODS:
kubectl get pods -n keycloak -w

====================================================

2. Backup in AKS (Cloud)
a) Database Backup

If using Azure Database for PostgreSQL → Enable automatic backups + point-in-time restore (PITR).

If self-managed Postgres in AKS:

kubectl exec -it postgres-pod -- \
  pg_dump -U keycloakuser -d keycloakdb > keycloak-backup.sql

b) Keycloak Realm Export

Run inside a Keycloak pod:

kubectl exec -it deploy/keycloak -- \
  /opt/keycloak/bin/kc.sh export --dir /tmp/backup --users realm_file
kubectl cp keycloak-pod:/tmp/backup ./keycloak-backup

c) PVC Snapshots

If using Azure Disk for persistence:

az snapshot create \
  --resource-group my-rg \
  --name keycloak-pvc-snapshot \
  --source <DISK_ID>

d) Secrets

Backup your Kubernetes secrets (DB password, TLS certs):

kubectl get secret pgsql-db-secret -o yaml > pgsql-db-secret-backup.yaml
kubectl get secret keycloak-tls -o yaml > keycloak-tls-backup.yaml

🐳 3. Backup in Docker (Local)
a) Database Dump
docker exec -t keycloak-db pg_dump -U keycloakuser -d keycloakdb > keycloak-backup.sql

b) Realm Export
docker exec -it keycloak /opt/keycloak/bin/kc.sh export \
  --dir /opt/keycloak/data/export --users realm_file
docker cp keycloak:/opt/keycloak/data/export ./keycloak-backup

c) Volumes

If Keycloak is using Docker volumes:

docker run --rm -v keycloak_data:/data -v $(pwd):/backup busybox \
  tar czf /backup/keycloak_data_backup.tar.gz /data

d) Keystores & Certs

If mounted into /etc/x509/https:

docker cp keycloak:/etc/x509/https ./cert-backup

🔄 4. Restore Plan

Database:

psql -U keycloakuser -d keycloakdb < keycloak-backup.sql


Realm Import:

/opt/keycloak/bin/kc.sh import --dir /opt/keycloak/data/import

=========================
## BAckup plan
1️⃣ What to Back Up

Database (Postgres/Yugabyte/MySQL)

All realms, users, roles, groups, federations, tokens are stored in DB.

Configuration Overrides

Helm values.yaml, Kubernetes manifests, Docker Compose files.

Keystores / Certificates

/opt/keycloak/conf/ JKS or PEM files for HTTPS and LDAP TLS.

Secrets

K8s Secrets (DB credentials, admin password, truststore passwords).

Persistent Volumes (if used)

For themes, custom providers, or SPI JARs mounted inside Keycloak.

2️⃣ Backup in AKS (Cloud)
🔐 Database

If using Azure Database for PostgreSQL:

Enable Point-in-Time Restore (PITR).

Or run scheduled pg_dump to Blob storage:

PGPASSWORD=$DB_PASS pg_dump -h mydb.postgres.database.azure.com -U keycloakuser -d keycloakdb > keycloak-$(date +%F).sql


Run via Kubernetes CronJob:

apiVersion: batch/v1
kind: CronJob
metadata:
  name: keycloak-db-backup
spec:
  schedule: "0 2 * * *"   # every day 2AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: pg-dump
            image: postgres:15
            command: ["sh", "-c"]
            args:
              - |
                PGPASSWORD=$POSTGRES_PASSWORD \
                pg_dump -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB \
                > /backups/keycloak-$(date +%F).sql
            envFrom:
              - secretRef:
                  name: pgsql-db-secret
            volumeMounts:
              - mountPath: /backups
                name: backup-volume
          restartPolicy: OnFailure
          volumes:
            - name: backup-volume
              persistentVolumeClaim:
                claimName: backup-pvc

🔑 Secrets
kubectl get secret pgsql-db-secret -o yaml > secret-backup.yaml
kubectl get secret keycloak -o yaml > kc-secret-backup.yaml

⚙️ Manifests

Keep Helm values.yaml, Ingress, Service, Deployment in Git repo.

🔒 Keystores

Mount Azure Disk/Azure File PVC with JKS. Backup via snapshot.

3️⃣ Backup in Docker (Local Dev)
🔐 Database

If using docker-compose with Postgres:

docker exec -t keycloak-postgres pg_dump -U keycloakuser keycloakdb > keycloak-local-$(date +%F).sql

⚙️ Configs

Keep docker-compose.yaml + .env in Git.

🔒 Keystores

Mount local directory into container:

volumes:
  - ./certs:/opt/keycloak/conf/certs


Back up that folder with Git or rsync.

4️⃣ Restore Plan

Cloud AKS

Restore from PITR or pg_restore.

Redeploy Keycloak Helm chart with same KC_DB_URL, KC_DB_USERNAME, KC_DB_PASSWORD.

Restore secrets:

kubectl apply -f secret-backup.yaml


Mount backed-up keystore PVC snapshot.

Local Docker

Restore DB:

docker exec -i keycloak-postgres psql -U keycloakuser -d keycloakdb < backup.sql


Restart Keycloak:

docker-compose up -d keycloak

✅ Recommended Combo

Production (AKS) → PITR on Postgres + nightly pg_dump CronJob + PVC snapshots for keystores.

Local (Docker) → pg_dump via Docker exec + keep compose files & certs in Git.

👉 Do you want me to write a ready-to-use AKS CronJob + Docker script bundle so you can schedule backups in both environments with the same approach?

====================================================
### Azure Network Security Groups (NSG) are used with AKS (Azure Kubernetes Service).
🔑 Key points first:
  - NSGs in Azure are applied at the subnet or NIC level in your AKS cluster’s Virtual Network (VNet).
  - AKS worker nodes (VMs) live inside a subnet. You can attach an NSG to that subnet to filter inbound/outbound traffic.
  - Pods themselves do not directly get NSGs. Instead, you control Pod-level networking with Kubernetes NetworkPolicies.
  - example scenario:
You want to allow only internal access to Keycloak in AKS, and block all external DB connections except port 5432 to PostgreSQL.

1. Create an NSG
>> bash: 
az network nsg create \
  --resource-group myResourceGroup \
  --name aks-subnet-nsg \
  --location eastus

2. Add inbound rule (allow PostgreSQL 5432 from Keycloak subnet only)
az network nsg rule create \
  --resource-group myResourceGroup \
  --nsg-name aks-subnet-nsg \
  --name Allow-Postgres-From-AKS \
  --priority 100 \
  --access Allow \
  --direction Inbound \
  --protocol Tcp \
  --source-address-prefixes 10.240.0.0/16 \
  --source-port-ranges '*' \
  --destination-port-ranges 5432


💡 Replace 10.240.0.0/16 with your AKS subnet range.

3. Block everything else inbound (deny rule)
az network nsg rule create \
  --resource-group myResourceGroup \
  --nsg-name aks-subnet-nsg \
  --name Deny-All-Inbound \
  --priority 4096 \
  --access Deny \
  --direction Inbound \
  --protocol '*' \
  --source-address-prefixes '*' \
  --destination-port-ranges '*'

4. Associate NSG with AKS subnet

First, find the subnet name:

az network vnet subnet list \
  --resource-group MC_myResourceGroup_myAKSCluster_eastus \
  --vnet-name aks-vnet \
  -o table


Then attach NSG:

az network vnet subnet update \
  --resource-group MC_myResourceGroup_myAKSCluster_eastus \
  --vnet-name aks-vnet \
  --name aks-subnet \
  --network-security-group aks-subnet-nsg

##   Result:
  - Your AKS worker nodes will now only allow DB traffic on 5432.
  - Use Kubernetes NetworkPolicies inside the cluster for pod-to-pod restrictions.
-----------------
🔹 Example: NetworkPolicy for Keycloak → PostgreSQL only
🔹 Explanation
  - podSelector: applies to all Keycloak pods (app: keycloak).
  - policyTypes: Egress → restricts what Keycloak can connect outbound.
  - egress rule: allows connections only to pods with label app: postgres in namespace database on TCP 5432.
  - ✅ Any other outbound traffic (e.g., Keycloak calling random services) will be blocked.

>> yaml:
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: keycloak-to-postgres
  namespace: keycloak
spec:
  podSelector:
    matchLabels:
      app: keycloak
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: postgres
      namespaceSelector:
        matchLabels:
          name: database
    ports:
    - protocol: TCP
      port: 5432

===================================================
## run AKS in Azure, the Network Security Groups (NSGs) apply at the subnet or node level, not directly to containers.

🔹 1. Identify Your AKS Cluster Subnet
# Get AKS cluster resource group
az aks show -n <aks-cluster-name> -g <resource-group> --query nodeResourceGroup -o tsv

🔹 2. List NSGs Attached to Subnet / NICs
# List NSGs applied to subnet
az network vnet subnet show --ids <subnet-id> --query "networkSecurityGroup" -o table

# List NSGs for all node NICs
az network nic list --resource-group <aks-node-rg> --query "[].{name:name, nsg:networkSecurityGroup.id}" -o table

🔹 3. View Rules in an NSG
# List all rules in a given NSG -> will show priority, direction (Inbound/Egress), port, protocol, and allow/deny.
az network nsg rule list --nsg-name <nsg-name> --resource-group <rg> -o table
##
🔹 4. Check Effective Rules on a Node NIC
If you want to see what’s really applied (after defaults + custom rules):
## This is the best way to debug connectivity (e.g. why Keycloak pod cannot reach Postgres on 5432).

>> bash:
  az network nic show-effective-nsg --name <nic-name> --resource-group <aks-node-rg> -o table
===============
## check if your AKS cluster nodes can reach Postgres on port 5432.
🔹 1. Find an AKS Node NIC
# Get the node resource group
NODE_RG=$(az aks show -n <aks-cluster-name> -g <aks-rg> --query nodeResourceGroup -o tsv)

# List NICs for your AKS nodes
az network nic list -g $NODE_RG -o table
1.2. Pick one NIC name from the list (e.g. aks-nodepool1-12345678-nic-0).
🔹 2. Run IP Flow Verify to Check Port 5432
az network watcher test-ip-flow \
  --resource-group $NODE_RG \
  --direction Outbound \
  --local <aks-node-private-ip> \
  --protocol TCP \
  --local-port 5432 \
  --remote <postgres-db-ip> \
  --remote-port 5432 \
  --nic <nic-name>
----------------  
🔹 3. Example
az network watcher test-ip-flow \
  -g MC_myAKSCluster_myResourceGroup_eastus \
  --direction Outbound \
  --local 10.240.0.4 \
  --protocol TCP \
  --local-port 5432 \
  --remote 10.10.1.5 \
  --remote-port 5432 \
  --nic aks-nodepool1-12345678-nic-0

✅ Output will say either:
  "Allow" → traffic to Postgres is permitted
  "Deny" → blocked by a specific NSG rule (you’ll see which one)
##  print all subnet IDs:
az network vnet subnet list \
  --resource-group <rg-name> \
  --vnet-name <vnet-name> \
  --query "[].id" -o tsv  
------------------------
### 🔹 5. Things to Remember
  - Containers don’t get NSGs directly — they inherit from the node’s NIC/subnet NSG.
  - If you’re using Azure CNI (not Kubenet), each pod gets an IP from the subnet → NSG applies.
  - If your DB (Postgres) is external, make sure your egress NSG allows TCP 5432.
  - If Postgres is in another subnet/VNet, check VNet peering rules + NSG on that subnet.  
===================================================
Architecture Diagram KAfka-LDAP-Keycloak-PGSQL

                              Internet
                                 |
                +----------------+----------------+
                |                                 |
           Azure Front Door / LB                  Admin Host
                |                                 |
           Ingress (NGINX/AGIC)                    |
                |                                 |
        ---------------------------               |
        |        AKS Cluster        |              |
        |  (namespace: keycloak)    |              |
        |  +--------------------+   |              |
        |  | Keycloak (5 pods)  |   |              |
        |  | - User Federation  |   |              |
        |  |   -> LDAP (AD DS)  |   |              |
        |  | - Infinispan (ext) |   |              |
        |  +---+--------------+-+ |              |
        |      |              |   |              |
        |      | LDAP (ldaps) |   |              |
        |      |              |   |              |
        |  +---v--------------v-+ |              |
        |  | Kafka (MSK/K8s)     | |              |
        |  | (separate namespace)| |              |
        |  | Producers/Consumers | |              |
        |  +---------------------+ |              |
        |                          |              |
        ----------------------------               |
                 |  ^  ^                             |
                 |  |  | (egress to DB via NSG)     |
           PodNetwork  |                             |
                       |                             |
             +---------v-----------------------------v-+
             |    Azure VNet (subnets) / NSG rules      |
             |  - AKS node subnet (NSG applied)         |
             |  - DB subnet (NSG, Restrict inbound)     |
             |  - LDAP / AD subnet (if on-prem / peered)|
             +-----------------------------------------+
                                 |
               Azure Database for PostgreSQL (PaaS)
               - port 5432 (SSL required, restricted NSG)

===================================================
Key components & responsibilities

Keycloak (AKS)

5 replicas, PodAntiAffinity + topologySpread (multi-AZ).

Uses User Federation → LDAP (AD/ADLS) to authenticate users.

Uses Infinispan (external or Kubernetes stack) for distributed cache.

Connects to external Azure Database for PostgreSQL (JDBC jdbc:postgresql://<host>:5432/<db>?sslmode=require).

Kafka

Either managed (Confluent/Azure Event Hubs for Kafka) or self-hosted in a separate namespace/statefulset.

Uses Keycloak for authorization (OAuth/OIDC) via a custom authorizer or through token verification in clients.

LDAP (Active Directory / LDAPS)

External (on-prem or Azure AD DS). Keycloak configured to talk LDAPS (port 636) to fetch users/groups.

Azure VNet & NSG

NSG on DB subnet allows only inbound 5432 from AKS node subnet (or specific firewall IPs).

NSG on AKS subnet allows outbound to PostgreSQL IP:5432 and LDAPS IP:636.

Optional jumpbox/public admin IPs for ops.

NetworkPolicies (K8s)

Pod-level egress rules in keycloak namespace allowing only DB IP:5432 and LDAP IP:636.

Kafka pods allowed to talk to Keycloak (port 8080/8443) as needed.

Concrete network/security rules (examples)
1) Azure NSG rule: allow AKS subnet → PostgreSQL (port 5432)
az network nsg rule create \
  --resource-group rg-network \
  --nsg-name nsg-db-subnet \
  --name Allow-AKS-To-Postgres \
  --priority 100 \
  --access Allow \
  --direction Inbound \
  --protocol Tcp \
  --source-address-prefixes <aks-subnet-cidr> \
  --source-port-ranges '*' \
  --destination-address-prefixes <postgres-private-ip-or-service-tag> \
  --destination-port-ranges 5432

2) Azure NSG rule: deny everything else inbound to DB subnet (default deny last)
az network nsg rule create \
  --resource-group rg-network \
  --nsg-name nsg-db-subnet \
  --name Deny-All-Inbound \
  --priority 4096 \
  --access Deny \
  --direction Inbound \
  --protocol '*' \
  --source-address-prefixes '*' \
  --destination-port-ranges '*'
---------------------------------------------------
4) If LDAP is in-cluster or in another namespace, use pod/namespace selectors instead of ipBlock.
Keycloak configuration pointers (practical)

KC_DB_URL: include SSL for Azure DB

jdbc:postgresql://<your-db-host>:5432/keycloakdb?sslmode=require


KC_DB_USERNAME for Azure DB may be user@servername (ensure correct username format).

LDAP Group Mapper: set membership.attribute.type=DN, membership.ldap.attribute=member for AD; use preserve.group.inheritance=false or multiple.parents.allowed=false if GroupsMultipleParents errors occur.

kcadm.sh automation: run as init job or use a startup wrapper script (pre-start → start Keycloak → post-start).

Kafka ↔ Keycloak authorization patterns

Options (choose one per your architecture):

Service-side token validation — Kafka clients validate JWT from Keycloak; Keycloak issues tokens via client_credentials or password grants.

Custom authorizer in Kafka — plugin that calls Keycloak introspection or verifies JWT for every request. (For high throughput prefer local JWT validation using public keys).

Proxy/auth sidecar — use Envoy or API gateway to enforce OIDC before requests hit Kafka.

Steps checklist for secure deployment

Provision VNet, subnets: aks-subnet, db-subnet, ldap-subnet.

Create NSGs and attach to subnets; tight inbound/outbound rules.

Deploy AKS with Azure CNI if you want pod IPs in VNet (useful for NSG granularity).

Deploy external Infinispan or configure KC_CACHE=kubernetes + stack.

Provision external PostgreSQL (Azure DB Flexible Server) with firewall rules to allow AKS node subnet. Enable SSL.

Create Kubernetes Secrets: DB creds, Keycloak TLS truststore, LDAP bind creds.

Deploy Keycloak via Helm values-ha.yaml (replicas=5), include extraEnv for KC_DB_URL, KC_DB_USERNAME, secret-ref password.

Apply NetworkPolicy to restrict egress from Keycloak to DB + LDAP only.

Configure LDAP federation and group mappers (via realm import or kcadm.sh post-start).

Configure Kafka integration: choose token flow and implement token validation or authorizer.

Useful commands (quick)

Get AKS node resource group:

az aks show -g <rg> -n <cluster> --query nodeResourceGroup -o tsv


Add DB firewall rule to allow AKS subnet:

az postgres flexible-server firewall-rule create -g <rg> -n <pg-server> -s AllowAKS --start-ip-address <start> --end-ip-address <end>


Verify DB connectivity from AKS:

kubectl run -it --rm pgtest --image=postgres:15 -- psql -h <db-host> -U <user> -d <db> "SELECT 1;"

Security & operational notes

Use private endpoints for Azure DB where possible (avoid public LB).

Use TLS for LDAP and Postgres. Ensure Keycloak truststore contains LDAP/DB CA.

Use PodDisruptionBudgets with 5 replicas to avoid mass disruption.

Monitor Keycloak and Infinispan metrics; add liveness/readiness probes and HPA if needed.

Keep secrets in Azure Key Vault and sync with Kubernetes via CSI driver for production.

## Possible options:
  - generate a one-file diagram (SVG/PNG) (I can provide the layout and steps 
  - produce Helm values + Kubernetes manifest snippets tailored to your real hostnames/IPs and AD paths, or
  - output a policy-as-code / Terraform snippet to wire VNet + NSG + AKS + Private Endpoint.

===================================================
5) Decode JWT in Postman (quick)
  You can decode the access token in Postman Tests tab with a small script to show payload:

// Paste this in the Tests tab after receiving a token response
const body = pm.response.json();
const token = body.access_token || body.id_token;
if (token) {
  const parts = token.split('.');
  const payload = JSON.parse(atob(parts[1].replace(/-/g,'+').replace(/_/g,'/')));
  console.log("JWT payload:", payload);
  pm.environment.set("kc_access_token", body.access_token);
  pm.test("JWT contains realm and username", () => {
    pm.expect(payload).to.have.property("preferred_username");
  });
}


Or paste access_token into https://jwt.io
 to inspect claims.
-----------------
6) Refresh token (Postman request)
  To refresh:
POST same token endpoint with:
>>
  grant_type=refresh_token
  client_id=my-client
  client_secret=<if confidential>
  refresh_token=<refresh_token_from_response> 


=================================
HPA =============================
=================================
hpa:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 100
          periodSeconds: 15
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 15
===================================================================
Script:
#!/bin/bash
# URL to hit
URL="http://localhost:8080/health"
# Number of times to run
COUNT=1000
for ((i=1; i<=COUNT; i++))
do
  echo "[$i] Running curl..."
  curl -s -o /dev/null -w "Status: %{http_code}\n" "$URL"
done

=============================================
Remove Authentication Direct Grand Flow:
🔎 Steps in Keycloak Admin Console
 - Login to the Keycloak Admin Console.
 - Navigate to:
    Authentication → Flows
 - Check if the flow you want to delete is set as the default binding:
 - Go to Authentication → Bindings.
 - Look at Direct Grant Flow, Browser Flow, etc.
 - If your custom flow is selected there, change it back to the built-in direct grant (or another valid flow).
 - Also check if any client is explicitly using that flow:
  - Go to Clients → <your client> → Authentication Flow Overrides.
  - Ensure your flow is not set there. If it is, unset or change it.
  - Once the flow is not referenced anywhere, go back to
Authentication → Flows, select your flow, and click Delete.
## #############
## 🛠 CLI (kcadm.sh) method
  
# Login as admin
kcadm.sh config credentials --server http://localhost:8080/auth \
  --realm master --user admin --password <password>

# List flows
kcadm.sh get authentication/flows -r <realm>

# If flow is bound, reset binding first
kcadm.sh update realms/<realm> -s "directGrantFlow=direct grant"

# Delete your custom flow by id or alias
kcadm.sh delete authentication/flows/<flow-id> -r <realm>
===========

✅ Rule of thumb:
  You can’t delete an authentication flow if:
  It is the default binding for Browser/Direct Grant/Reset Credentials.
  It is set on a client override.
  Once detached, deletion works.

## safe cleanup script using Keycloak’s kcadm.sh CLI that:
  Logs into Keycloak
  Detects if the target flow is bound to Direct Grant, Browser, or Reset Credentials
  Resets those bindings back to defaults
  Checks client overrides and resets them if needed
  Deletes the flow safely
-----------

# Usage: ./delete-flow.sh <realm> "<flow-alias>"
>> BASH:
#!/bin/bash

REALM=$1
FLOW_ALIAS=$2

if [[ -z "$REALM" || -z "$FLOW_ALIAS" ]]; then
  echo "Usage: $0 <realm> \"<flow-alias>\""
  exit 1
fi

# Path to kcadm.sh (adjust if needed)
KC_BIN=/opt/keycloak/bin/kcadm.sh

# Login as Keycloak admin (adjust user/pass/server/realm)
$KC_BIN config credentials --server http://localhost:8080 \
  --realm master --user admin --password 'admin'

echo " Checking flows in realm '$REALM'..."
FLOW_ID=$($KC_BIN get authentication/flows -r $REALM | jq -r ".[] | select(.alias==\"$FLOW_ALIAS\") | .id")

if [[ -z "$FLOW_ID" ]]; then
  echo " Flow '$FLOW_ALIAS' not found in realm '$REALM'."
  exit 1
fi

echo " Found flow '$FLOW_ALIAS' with id: $FLOW_ID"

# Step 1: Reset realm bindings if this flow is in use
echo "🔎 Checking realm authentication bindings..."
REALM_CFG=$($KC_BIN get realms/$REALM)

for BINDING in browserFlow directGrantFlow resetCredentialsFlow; do
  CUR_FLOW=$(echo "$REALM_CFG" | jq -r ".$BINDING")
  if [[ "$CUR_FLOW" == "$FLOW_ALIAS" ]]; then
    echo " Flow '$FLOW_ALIAS' is set as $BINDING. Resetting to default..."
    $KC_BIN update realms/$REALM -s "$BINDING=direct grant"
  fi
done

# Step 2: Check client overrides
echo "🔎 Checking clients using flow overrides..."
CLIENTS=$($KC_BIN get clients -r $REALM)
for CID in $(echo "$CLIENTS" | jq -r '.[].id'); do
  CLIENT=$($KC_BIN get clients/$CID -r $REALM)
  OVERRIDE=$(echo "$CLIENT" | jq -r '.authenticationFlowBindingOverrides | .direct_grant')
  if [[ "$OVERRIDE" == "$FLOW_ALIAS" ]]; then
    echo "⚠️ Client $(echo $CLIENT | jq -r .clientId) overrides direct grant with '$FLOW_ALIAS'. Resetting..."
    $KC_BIN update clients/$CID -r $REALM -s 'authenticationFlowBindingOverrides.direct_grant=direct grant'
  fi
done

# Step 3: Delete the flow
echo "🗑 Deleting flow '$FLOW_ALIAS'..."
$KC_BIN delete authentication/flows/$FLOW_ID -r $REALM

echo "✅ Flow '$FLOW_ALIAS' deleted successfully!"

## Delete REALM:
chmod +x delete-realm.sh
./delete-realm.sh

===========================================================
## LOAD TEST
## use: templates/keycloak-load-cronjob.yaml
## use: tempalte/values.yaml

📌 Deploy the load job
>> bash:
helm upgrade --install keycloak-load ./mychart -f values.yaml
## >> This will schedule a job every 2 minutes that hits Keycloak with requests load in concurrent batches.

## 2 Option Use kubectl run with a loop of curl
>>   This will continuously hit Keycloak until you stop it (Ctrl+C).
>> 
kubectl run keycloak-load --rm -it --image=busybox --restart=Never -- \
  sh -c "while true; do 
    wget -q -O- http://keycloak-service:8080/auth/realms/master; 
  done"



## 2. option
5. 🧩 Kubernetes-native stress with stress-ng
   run stress-ng inside a pod targeting CPU:
   This doesn’t hit Keycloak directly, but if you run it inside the Keycloak pod (e.g., kubectl exec) it will spike CPU artificially so HPA triggers scaling.

>> 
kubectl run stress --rm -it --image=alpine/stress-ng -- \
  stress-ng --cpu 4 --io 2 --vm 2 --timeout 300s

=========================================================================
Direct Access Grant Authorization in Keycloak

>>Client sends:
  POST /realms/<realm>/protocol/openid-connect/token
  grant_type=password
  client_id=my-client
  username=user1
  password=secret
-------------------------
🔐 Direct Access Grant with Certificate (Mutual TLS)
 -  If you want to use client certificates for authentication (mTLS), 
    Keycloak supports this via Client Authentication → X.509 certificates.
- This lets Keycloak validate the client identity using the presented certificate instead of a shared secret.

🧩 Steps to Create Direct Access Grant Client with Certificate via Bash
    Below is a pure bash script using kcadm.sh (Keycloak’s admin CLI).
🧱 Requirements:
  - You must be logged in to the admin CLI (kcadm.sh config credentials ...)
  - You already have your .crt and .key files ready for the client


## Step 1: Create the client
REALM="kafka-dev"
CLIENT_ID="my-direct-client"

# 1. Create client with Direct Access Grants enabled
/opt/keycloak/bin/kcadm.sh create clients -r "$REALM" \
  -s clientId="$CLIENT_ID" \
  -s publicClient=false \
  -s 'directAccessGrantsEnabled=true' \
  -s 'serviceAccountsEnabled=true' \
  -s 'standardFlowEnabled=false' \
  -s 'protocol=openid-connect'

# 2. Step 2: Enable Certificate-based Authentication (mTLS)
  Keycloak expects the client certificate to be uploaded as an attribute or credential.
  You can link a certificate by setting the client’s X.509 attribute:
>> bash:
CLIENT_UUID=$(/opt/keycloak/bin/kcadm.sh get clients -r "$REALM" --query clientId=$CLIENT_ID --fields id --format csv | head -1 | cut -d',' -f1)

CERT_CONTENT=$(cat /path/to/client.crt | sed ':a;N;$!ba;s/\n/\\n/g')

/opt/keycloak/bin/kcadm.sh update clients/$CLIENT_UUID -r "$REALM" \
  -s 'attributes."x509.subjectdn"="CN=my-direct-client,O=MyOrg"' \
  -s 'attributes."tls.client.certificate"="'"$CERT_CONTENT"'"'

# 3. Step 3: Optionally Require Client Certificate Authentication
  This enforces certificate validation when this client requests tokens:
/opt/keycloak/bin/kcadm.sh update clients/$CLIENT_UUID -r "$REALM" \
  -s 'authenticationFlowBindingOverrides.directGrant="browser-flow-mtls"'
## Or create a custom authentication flow bound to mutual TLS login.

# 4. Step 4: Test the Direct Access Grant (Password or mTLS)
# 4.1. Password grant
curl -k -X POST "https://keycloak.example.com/realms/$REALM/protocol/openid-connect/token" \
  -d "client_id=$CLIENT_ID" \
  -d "grant_type=password" \
  -d "username=user1" \
  -d "password=secret"
# 4.2. mTLS grant:
curl -k --cert /path/to/client.crt --key /path/to/client.key \
  -X POST "https://keycloak.example.com/realms/$REALM/protocol/openid-connect/token" \
  -d "client_id=$CLIENT_ID" \
  -d "grant_type=client_credentials"
=================================================
### self-contained, dependency-free bash script that:
  - Creates a realm (if missing)
  - Creates a client with Direct Access Grants enabled
  - Configures mTLS (client certificate) attributes
  - Retrieves the client UUID
  - Tests the token endpoint using password or certificate
  - 👉 No jq or awk used — only sed, cut, and grep.


## bash: create-direct-client-mtls.sh
>> run:
  chmod +x create-direct-client-mtls.sh
  ./create-direct-client-mtls.sh

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
# 6. Attach Certificate Attributes
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
echo "🧪 Testing mTLS client credentials..."
curl -k --cert "$CRT_PATH" --key "$KEY_PATH" \
  -X POST "$KC_URL/realms/$REALM/protocol/openid-connect/token" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" | sed 's/{/\n{/g'

echo "✅ Done."
========================================================================
## Create-kafka-direct-grant.sh
This script will:

✅ Create (or verify) a realm
✅ Create the Kafka-direct-grant client with Direct Access Grants + mTLS
✅ Attach the bank certificate attributes
✅ Test the token retrieval via both password and client certificate grant

No jq or awk dependencies — only sed, grep, and standard bash tools.

## FIx null when creting execution :
null [No authentication provider  found for id: x509-username ]
## Option 1 — Add environment variable (recommended)
# In your Docker or Helm values:
env:
  - name: KC_FEATURES
    value: "x509-auth"
# Or in Docker CLI:
  docker run -e KC_FEATURES=x509-auth ...

# Switch to root so we can copy files and install packages if needed
USER root

# Download the official X.509 provider JAR and place it into providers directory
RUN mkdir -p /opt/keycloak/providers && \
    curl -L -o /opt/keycloak/providers/keycloak-x509-user-lookup-26.0.0.jar \
    https://github.com/keycloak/keycloak/releases/download/26.0.0/keycloak-x509-user-lookup-26.0.0.jar

# Rebuild Keycloak to register the provider
RUN /opt/keycloak/bin/kc.sh build --features=x509

# Back to keycloak user for runtime
USER keycloak

# Start command
ENTRYPOINT ["/opt/keycloak/bin/kc.sh", "start", "--hostname-strict=false", "--features=x509"]


{
  "id": "x509-username",
  "displayName": "X509/Validate Username",
  "description": "Validates users based on the X509 client certificate."
}

[ {
  "id": "12345",
  "requirement":"DISABLED",
  "displayName": "X509/Validate Username Form",
  "requirementChoices": [ "REQUIRED", "ALTERNATIVE", "DISABLED" ],
  "configurable": true,
  "providerId" : "auth-x509-client-username-form",
  "level" : 0,
  "index" : 1
},... ]

[{
  "id": "myrealm",
  "realm": "myrealm"
},...]

[{
  "name": "${client_account}",
  "rootUrl": "${authBaseUrl}"
},...]

CLEANED=$(echo "$REALMS_JSON" | tr -d ' ' | tr -d '"' )

# Find matching realm block and extract id
# Example input: [{"id":"master","realm":"master"},{"id":"kafka-dev","realm":"kafka-dev"}]
REALM_ID=$(echo "$CLEANED" | sed -n "s/.*id:\([^,}]*\),realm:$REALM_NAME.*/\1/p")
ESCAPED_REALM=$(printf '%s\n' "$REALM_NAME" | sed 's/[][\.^$*\/]/\\&/g')

REALM_ID=$(printf '%s\n' "$CLEANED" |
  sed -n "/\"realm\": *\"$ESCAPED_REALM\"/{N; s/.*\"id\": *\"\([^\"]*\)\".*/\1/p}"
)
REALM_ID=$(printf '%s\n' "$CLEANED" | sed -n "s/.*\"id\"[ ]*:[ ]*\"\([^\"]*\)\"[^{]*\"realm\"[ ]*:[ ]*\"$REALM_NAME\".*/\1/p")
REALM_ID=$(printf '%s\n' "$CLEANED" | sed -n "s/.*\"id\":\"\([^\"]*\)\"[^{]*\"realm\":\"$REALM_NAME\".*/\1/p")

#!/bin/bash
set -e

KC_URL="http://localhost:8080"
REALM_NAME="myrealm"
ADMIN_USER="admin"
ADMIN_PASS="admin123"
CLIENT_ID="admin-cli"

# === 1. Get Admin Token ===
TOKEN=$(curl -s -X POST "${KC_URL}/realms/master/protocol/openid-connect/token" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASS}" \
  -d "grant_type=password" \
  \
  
  | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')

if [ -z "$TOKEN" ]; then
  echo "❌ Failed to get access token"
  exit 1
fi

# === 2. Get Realms JSON ===
REALMS_JSON=$(curl -s -X GET "${KC_URL}/admin/realms" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json")

# === 3. Extract "id" by "realm" ===
REALM_ID=$(echo "$REALMS_JSON" | tr -d '\n' | sed -n "s/.*\"realm\":\"${REALM_NAME}\"[^{]*\"id\":\"\([^\"]*\)\".*/\1/p")

if [ -z "$REALM_ID" ]; then
  echo "❌ Realm '${REALM_NAME}' not found"
  exit 1
fi

echo "✅ Realm '${REALM_NAME}' ID: ${REALM_ID}"
=========================================================================
HARSHICORP VOULT use admin creds in kubernetes to start Docker container:
Vault path is secret/data/keycloak-admin and it contains:
  vault kv put secret/keycloak-admin username=admin password=SuperSecret123
You can fetch secrets using the Vault CLI or Agent and create a Kubernetes Secret dynamically.
## Option A: Simple manual (for test/dev)
# Fetch values from Vault
USERNAME=$(vault kv get -field=username secret/keycloak-admin)
PASSWORD=$(vault kv get -field=password secret/keycloak-admin)

# Create Kubernetes Secret
kubectl create secret generic keycloak-admin-creds \
  --from-literal=username=$USERNAME \
  --from-literal=password=$PASSWORD
--------------
Option B: Auto-inject via Vault Agent Injector (recommended)
  Annotate your Keycloak Deployment so Vault auto-injects the credentials file:
>> yaml:
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak
spec:
  replicas: 1
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "keycloak-role"
        vault.hashicorp.com/agent-inject-secret-admin.txt: "secret/data/keycloak-admin"
    spec:
      containers:
        - name: keycloak
          image: quay.io/keycloak/keycloak:latest
          command: ["/opt/start.sh"]
          volumeMounts:
            - name: vault-secrets
              mountPath: /vault/secrets
      volumes:
        - name: vault-secrets
          emptyDir: {}
# Then inside the container, the file /vault/secrets/admin.txt will contain:
  username=admin
  password=SuperSecret123
Step 3 — Create ConfigMap for start.sh

apiVersion: v1
kind: ConfigMap
metadata:
  name: keycloak-startup
data:
  start.sh: |
    #!/bin/bash
    source /vault/secrets/admin.txt
    echo "Starting Keycloak with user $username"
    /opt/keycloak/bin/kc.sh start --hostname-strict=false \
      --spi-admin-console-theme=keycloak \
      --admin-username=$username \
      --admin-password=$password
>> Then mount this ConfigMap as an executable file:

volumeMounts:
  - name: start-script
    mountPath: /opt/start.sh
    subPath: start.sh
    readOnly: true
volumes:
  - name: start-script
    configMap:
      name: keycloak-startup
      defaultMode: 0755
## ⚙️ Step 4 — Verify
When the Pod starts:
Vault Agent injects the creds file.
  start.sh sources it.
Keycloak runs with admin creds from Vault — no plaintext secrets in YAML.


=========================================================================
VAULT  Agent or Injector  for Kubernetes:
-------------------------------------------------------------------------
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak
spec:
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "keycloak-role"
        vault.hashicorp.com/agent-inject-secret-ldap: "secret/data/ldap"
        vault.hashicorp.com/agent-inject-template-ldap: |
          {{- with secret "secret/data/ldap" -}}
          {
            "bindCredential": ["{{ .Data.data.ldapCredential }}"]
          }
          {{- end }}
## ----
vault.hashicorp.com/agent-inject-template-ldap: |
  {{- with secret "secret/data/ldap" -}}
  {
    "bindCredential": ["{{ .Data.data.ldapCredential }}"],
    "bindCredentialBase64": ["{{ base64Encode .Data.data.ldapCredential }}"]
  }
  {{- end }}          
## ====
👉 This will auto-generate a file like /vault/secrets/ldap in your pod.
  Then, in your bash script, just read from that file:
>> bash
LDAP_CREDENTIAL=$(grep -oP '(?<="bindCredential": \[")[^"]+' /vault/secrets/ldap)

===========================================================================
Rotate admin password:
✅ Option A: Change password using kcadm.sh
    If you’re logged in as admin (or using a valid config):
>>
/opt/keycloak/bin/kcadm.sh update users/<admin_user_id> \
    -r master \
    -s "credentials=[{'type':'password','value':'<new_password>','temporary':false}]" \
    --config /tmp/kcadm.config

✅ Option B: Reset password from inside the Pod
    If your admin password is injected from env vars (e.g., Kubernetes Secret), rotate it like this:
>>
  kubectl get secret keycloak-admin-creds -o yaml
  # edit the secret (base64 encode the new password)
  kubectl edit secret keycloak-admin-creds
  # restart pod to apply new env var
  kubectl rollout restart deployment keycloak
---
🧩 2. Use a Token Instead of Password with kcadm.sh

You can authenticate with a Bearer token instead of a username/password combo.

✅ Step 1: Get a token
TOKEN=$(curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=$ADMIN_PASS" \
  -d "grant_type=password" | grep -oP '(?<="access_token":")[^"]+')

✅ Step 2: Use token with kcadm.sh
/opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 \
  --realm master \
  --client admin-cli \
  --token "$TOKEN"

This will write the token to your /tmp/kcadm.config, and subsequent commands will use it automatically:

/opt/keycloak/bin/kcadm.sh get realms --config /tmp/kcadm.config

-----
🧩 3. Automating Rotation + Token Setup
  can wrap this logic in a bash script like using:
  >>
    config/rotate-admin.sh:

=========================================================================
I get null [execution parent flow does nor exist] when using ADD_OUT=$($KCADM create authentication/executions \ -r "$REALM" \ -s "authenticator=$ACTION" \ -s "parentFlow=$FLOW_ALIAS" \ -s "requirement=ALTERNATIVE" 2>&1 || true) but flow exists and it prints it in json when I send get request kcadm.sh get authentication/flows ...


=========================================================================
XXXXXXXXXXXXXXXXXXXXXXXXX..................XXXXXXXXXXXXXXXXXXXXXXXX

    - Add automatic Let's Encrypt certs?
    - Enable Kubernetes/AKS secret-based keystore loading?

 Postman Collection to test this setup
 Add Infinispan or YugabyteDB
 Helm chart version for AKS
 Kubernetes initContainer
 entrypoint.sh to prevent Keycloak booting if LDAP isn’t reachable


    -  postman_collection.json file for download?
    - Newman-based shell script for 100 users?
    - Docker-based LDAP + Keycloak simulator for full testing?

    - Map users → groups using either LDAP’s native mappingdn
    - Map users → groups using either LDAP’s native mappingdn
    - Map users → groups using either LDAP’s native mappingdn
    - Map users → groups using either LDAP’s native mappingdn

===============================================    

X509 username mapper?

X509 certificate attribute mappers?

Auto-create client if missing?

Auto-attach flow?