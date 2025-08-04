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
  --env-var "realm_name=demo" \
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






-------------------------------------------------------------
XXX. postman_collection.json file for download?
     Newman-based shell script for 100 users?
     Docker-based LDAP + Keycloak simulator for full testing?