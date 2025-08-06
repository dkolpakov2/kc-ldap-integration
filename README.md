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
COPY ldap-truststore.jks /etc/x509/https/

# Optional: copy healthcheck
COPY healthcheck.sh /opt/keycloak/tools/healthcheck.sh
RUN chmod +x /opt/keycloak/tools/healthcheck.sh



-----------------------------------------
User:
  dmitry: 3b7f0b48-5b08-4ab8-b34f-2e866a7325df
  pass: admin
-------------------------------------------------------------
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