#!/bin/bash
set -e

TRUSTSTORE_PATH="/etc/x509/https/ldap-truststore.jks"
TRUSTSTORE_PASS="changeit"
LDAP_HOST="ldap"
LDAP_PORT="636"
LDAP_USER_DN="cn=admin,dc=planetexpress,dc=com"
LDAP_PASSWORD="GoodNewsEveryone"

# 1. Check truststore file exists
if [[ ! -f "$TRUSTSTORE_PATH" ]]; then
  echo " Truststore file not found: $TRUSTSTORE_PATH"
  exit 1
fi

# 2. Test LDAPS connection using OpenSSL
echo | openssl s_client -connect "${LDAP_HOST}:${LDAP_PORT}" -CAfile "$TRUSTSTORE_PATH" -quiet
if [[ $? -ne 0 ]]; then
  echo " Failed to connect to LDAPS at ${LDAP_HOST}:${LDAP_PORT}"
  exit 1
fi

# 3. Optionally: validate bind with Java + JNDI (if you want full auth check)
java <<EOF
import javax.naming.*;
import javax.naming.directory.*;
import java.util.*;

public class LdapBindCheck {
    public static void main(String[] args) {
        Hashtable<String, String> env = new Hashtable<>();
        env.put(Context.INITIAL_CONTEXT_FACTORY, "com.sun.jndi.ldap.LdapCtxFactory");
        env.put(Context.PROVIDER_URL, "ldaps://${LDAP_HOST}:${LDAP_PORT}");
        env.put(Context.SECURITY_AUTHENTICATION, "simple");
        env.put(Context.SECURITY_PRINCIPAL, "${LDAP_USER_DN}");
        env.put(Context.SECURITY_CREDENTIALS, "${LDAP_PASSWORD}");
        env.put("java.naming.ldap.factory.socket", "javax.net.ssl.SSLSocketFactory");

        try {
            new InitialDirContext(env);
            System.out.println(" LDAP bind successful");
        } catch (Exception e) {
            System.err.println(" LDAP bind failed: " + e.getMessage());
            System.exit(1);
        }
    }
}
EOF
