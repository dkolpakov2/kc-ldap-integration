#!/bin/bash

/opt/keycloak/bin/kc.sh start-dev &

# Wait for Keycloak to boot
until curl -s http://localhost:8080/health/ready | grep "UP"; do
  echo "Waiting for Keycloak to be ready..."
  sleep 5
done

/opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 \
  --realm master --user admin --password admin

/opt/keycloak/bin/kcadm.sh create components -r master \
  -s name=ldap \
  -s providerId=ldap \
  -s providerType=org.keycloak.storage.UserStorageProvider \
  -s parentId=$( /opt/keycloak/bin/kcadm.sh get realms/master --fields id -o csv --noquotes ) \
  -s 'config.vendor=["other"]' \
  -s 'config.connectionUrl=["ldap://ldap:389"]' \
  -s 'config.usersDn=["ou=users,dc=example,dc=org"]' \
  -s 'config.bindDn=["cn=admin,dc=example,dc=org"]' \
  -s 'config.bindCredential=["admin"]' \
  -s 'config.authType=["simple"]' \
  -s 'config.searchScope=["1"]'

wait