FROM registry.access.redhat.com/ubi8/ubi:latest

LABEL maintainer="you@example.com"

# Set environment variables
ENV KEYCLOAK_VERSION=24.0.3 \
    KC_HOME=/opt/keycloak \
    JAVA_HOME=/usr/lib/jvm/java-17 \
    LANG=en_US.UTF-8 \
    #!/bin/bash
    # Set Keycloak admin credentials and host info
    KEYCLOAK_URL="http://localhost:8080" \
    KEYCLOAK_REALM="master" \
    KEYCLOAK_USER="admin" \
    KEYCLOAK_PASS="admin" \
    LDAP_CONFIG_FILE="ldap-config.json" \
    KCADM="./bin/kcadm.sh"
    # Path to your JSON config (must be in importable format)
    

    # Path to kcadm.sh - adjust if needed
    

    # Login to Keycloak
$KCADM config credentials --server "$KEYCLOAK_URL" \
  --realm "$KEYCLOAK_REALM" \
  --user "$KEYCLOAK_USER" \
  --password "$KEYCLOAK_PASS"

    # Import the LDAP component JSON into the master realm
$KCADM create components -r "$KEYCLOAK_REALM" -f "$LDAP_CONFIG_FILE"


# Install system dependencies
RUN yum install -y \
      unzip \
      openssl \
      nss-tools \
      java-17-openjdk \
      curl \
      ca-certificates \
      shadow-utils \
    && yum clean all

# Download and extract Keycloak manually
RUN curl -L https://github.com/keycloak/keycloak/releases/download/${KEYCLOAK_VERSION}/keycloak-${KEYCLOAK_VERSION}.tar.gz -o /tmp/keycloak.tar.gz && \
    mkdir -p /opt && \
    tar -xzf /tmp/keycloak.tar.gz -C /opt && \
    mv /opt/keycloak-${KEYCLOAK_VERSION} ${KC_HOME} && \
    rm /tmp/keycloak.tar.gz

# Optional: create non-root user and change permissions
RUN useradd -u 1000 keycloak && \
    chown -R keycloak:keycloak ${KC_HOME}

USER admi#n
COPY config/ /opt/keycloak/
COPY config/entrypoint-configure /opt/keycloak/entrypoint-configure
RUN chmod +x /opt/keycloak/configure-ldap.sh /opt/keycloak/entrypoint-configure

# Copy JKS files into the image (optional)
COPY my-keystore.jks /etc/x509/https/my-keystore.jks
COPY ldap-truststore.jks /etc/x509/https/ldap-truststore.jks

# Create HTTPS cert directory if needed
RUN mkdir -p /etc/x509/https/ && \
    chmod 755 /etc/x509/https/

# Set Keycloak to run in development mode for now
ENV PATH="${KC_HOME}/bin:${PATH}" \
    KC_DB=dev-file \
    KC_HTTPS_KEY_STORE_FILE=/etc/x509/https/my-keystore.jks \
    KC_HTTPS_KEY_STORE_PASSWORD=changeit \
    KC_HTTPS_KEY_STORE_TYPE=JKS \
    JAVA_OPTS_APPEND="-Djavax.net.ssl.trustStore=/etc/x509/https/ldap-truststore.jks \
                      -Djavax.net.ssl.trustStorePassword=changeit \
                      -Djavax.net.ssl.trustStoreType=JKS"

#  Add a healthcheck script
# COPY healthcheck.sh /opt/keycloak/tools/healthcheck.sh
# RUN chmod +x /opt/keycloak/tools/healthcheck.sh

# Switch to keycloak user
USER 1000

# Start Keycloak
#ENTRYPOINT ["kc.sh"]
#CMD ["start-dev"]
ENTRYPOINT ["/opt/keycloak/configure-ldap.sh"]
