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

