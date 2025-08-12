#!/bin/bash

##  Best Dev Practice: For a disposable H2 DB, don’t mount a persistent volume for /opt/keycloak/data. 
# This way, every docker-compose up with --force-recreate starts fresh.
##prerequisite
docker run --name keycloak \
  -p 8080:8080 \
  quay.io/keycloak/keycloak:24.0.5 \
  start-dev


echo "Clearing H2 database..."
rm -f /opt/keycloak/data/h2/keycloakdb.mv.db
exec /opt/keycloak/bin/kc.sh start-dev

Drop users from H2 via SQL (less common for dev)
If you want to delete users without deleting the DB file:

## bash
docker exec -it keycloak \
  java -cp /opt/keycloak/lib/lib/* org.h2.tools.Shell \
  -url jdbc:h2:/opt/keycloak/data/h2/keycloakdb \
  -user sa \
  -password password \
  -sql "DELETE FROM USER_ENTITY"