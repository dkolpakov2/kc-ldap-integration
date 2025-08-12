#!/bin/bash
/opt/keycloak/bin/kc.sh start-dev &
KEYCLOAK_PID=$!

# Wait for Keycloak to be ready
until curl -s http://localhost:8080/realms/master; do
    sleep 5
done

# Trigger group sync for the LDAP provider
/opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user admin --password admin
/opt/keycloak/bin/kcadm.sh create user-storage/$LDAP_PROVIDER_ID/sync?action=triggerFullSync -r myrealm

wait $KEYCLOAK_PID
