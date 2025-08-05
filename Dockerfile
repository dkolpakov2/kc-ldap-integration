FROM accountid.dkr.ecr.us-east-1.amazonaws.com/accountid-qa-ecr:iac-svc
# ex:docker build --no-cache -f Dockerfile -t jboss/keycloak:latest .
# ex:docker tag 123 aws_account_id.dkr.ecr.region.amazonaws.com/keycloak
# ex:docker push aws_account_id.dkr.ecr.region.amazonaws.com/keycloak
# docker build -f Dockerfile -t accountid-ecr:iac-svc .
# aws --profile newdev ecr get-login-password --region us-east-1 --no-verify-ssl | docker login --username AWS --password-stdin accountid.dkr.ecr.us-east-1.amazonaws.com
FROM quay.io/keycloak/keycloak:24.0
# Optional: change user back to root to copy files
USER root
# Copy keystore
COPY my-keystore.jks /opt/keycloak/conf/
COPY ldap-truststore.jks /opt/keycloak/conf/
# Restore user if needed
USER 1000

RUN mkdir -m777 /opt/jboss/newrelic
RUN rm /opt/jboss/keycloak/standalone/deployments/keycloak-javascripts.jar
# COPY script/keycloak-javascripts.jar /opt/jboss/keycloak/standalone/deployments/
#COPY script/docker-entrypoint.sh /opt/jboss/keycloak/docker-entrypoint.sh
ARG env
COPY newrelic/$env/newrelic.yml /opt/jboss/newrelic/newrelic.yml
COPY config-keycloak/standalone.xml /opt/jboss/keycloak/standalone/configuration/standalone.xml
COPY config-keycloak/standalone-ha.xml /opt/jboss/keycloak/standalone/configuration/standalone-ha.xml

ENV keycloak.profile.feature.upload_scripts enabled

# -Djavax.net.debug=all
ENV  JAVA_OPTS -Dkeycloak.profile.feature.upload_scripts=enabled -javaagent:/opt/jboss/newrelic/newrelic.jar -Dnewrelic.environment=$env \
        ${JAVA_OPTS}
ENV DB_VENDOR postgres


EXPOSE 8080
EXPOSE 8443
EXPOSE 5432