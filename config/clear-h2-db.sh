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


#  you have id, names list in file and  want only the realmOne id using sed, you can do:
  sed -n '/,realmOne *$/s/,.*//p' realms.csv
  
#  If your CSV has quotes like "123","realmOne", you can strip the quotes first:
sed -n '2,3s/"\([^"]*\)".*/\1/p' file.csv

#and you want only the realmOne id using sed, you can do:
# keep just name in var
VAR="1111-aaaa-bbbb-cccc,realmOne"
VAR=$(echo "$VAR" | sed 's/^[^,]*,//')
echo "$VAR"

