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

    # Copy your custom entrypoint script
    COPY entrypoint.sh /opt/keycloak/entrypoint.sh
    RUN chmod +x /opt/keycloak/entrypoint.sh

    # Pre-build the Keycloak distribution (required for running commands in custom images)
    RUN /opt/keycloak/bin/kc.sh build

    # Use your custom entrypoint
    ENTRYPOINT ["/opt/keycloak/entrypoint.sh"]
------------------------------------------
>> entrypoint.sh
----------------
  FROM quay.io/keycloak/keycloak:24.0.1
  # Set workdir for scripts
  WORKDIR /opt/keycloak
  # Copy your custom entrypoint script
  COPY entrypoint.sh /opt/keycloak/entrypoint.sh
  RUN chmod +x /opt/keycloak/entrypoint.sh
  # Pre-build the Keycloak distribution (required for running commands in custom images)
  RUN /opt/keycloak/bin/kc.sh build
  # Use your custom entrypoint
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
  - Your LDAP user objects have membership attributes like memberOf or group entries contain member attributes.
  - Add Group Mapper in Keycloak Admin Console
    Go to:
      - User Federation → <Your LDAP provider name> → Mappers → Create
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

sed -i "s/PUT_YOUR_LDAP_PROVIDER_ID_HERE/$LDAP_PROVIDER_ID/" ldap-group-config.json

./kcadm.sh create components -r master -f ldap-group-config.jsonadmin     

## Group mapping :
# 1. Get your LDAP provider ID
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

ldapsearch -H ldap://your-ad-server -D "binduser@example.com" -w "password" \
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

=============================================================
== DB PostgreSQL=============================================
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

XXX. 
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