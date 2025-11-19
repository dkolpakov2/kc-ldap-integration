✅ 1. Can Kafka connect directly to LDAP?

Yes — Apache Kafka can authenticate directly to LDAP, but not natively.

Kafka does not have built-in LDAP support, but you can enable LDAP via:

Option A — Kafka SASL/PLAIN + LDAP (Auth via JAAS LoginModule)

Kafka brokers can authenticate users against LDAP using:

org.apache.kafka.common.security.plain.PlainLoginModule

A custom JAAS module that validates credentials against LDAP

This is commonly done via Kafka Authentication Plugins, such as:

Plugin	Description
Confluent LDAP Authorizer	LDAP groups → Kafka ACLs
Strimzi LDAP User Operator	Generates Kafka users from LDAP
Custom JAAS LDAP LoginModule	Direct LDAP bind authentication

But Kafka Open Source does NOT include an LDAP login module out-of-the-box.

✔ Works
✘ No OAuth2 / no tokens
✘ Groups mapping depends on plugin

❌ 2. Can Kafka authorize / ACL using LDAP directly?

No — Kafka cannot natively map LDAP groups → Kafka ACLs.

You need:

Confluent LDAP Authorizer, or

Custom plugin, or

Mirror LDAP → Kafka ACLs manually.

✅ 3. Why use Keycloak between Kafka and LDAP?

Using Keycloak gives you:

Feature	LDAP Only	Keycloak
| Feature                           | LDAP Only | Keycloak |
| --------------------------------- | --------- | -------- |
| Authentication                    | ✔         | ✔        |
| LDAP sync                         | ✔         | ✔        |
| **SSO / JWT tokens**              | ❌         | ✔        |
| **OAuth2 / OIDC**                 | ❌         | ✔        |
| Central user/role mapping         | ❌         | ✔        |
| Fine-grained permissions          | ❌         | ✔        |
| REST API for client management    | ❌         | ✔        |
| Federated identity flows          | ❌         | ✔        |
| Consistent config across clusters | ❌         | ✔        |


So Keycloak is recommended in complex multi-cluster Kafka deployments.

🔌 4. How Keycloak integrates with Kafka

Kafka supports OAuth2/OIDC via:

Strimzi OAuth2 plugin

Confluent Kafka OAuthBearer LoginModule

Custom OAuth plugins

Kafka Broker → Keycloak (OAuthBearer)
listeners=SASL_OAUTHBEARER://:9094
sasl.mechanism=OAUTHBEARER
sasl.enabled.mechanisms=OAUTHBEARER

sasl.login.callback.handler.class=io.strimzi.kafka.oauth.client.JaasClientOauthLoginCallbackHandler

Client JAAS (Producer/Consumer)
sasl.mechanism=OAUTHBEARER
security.protocol=SASL_PLAINTEXT
sasl.jaas.config=org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required \
  oauth.token.endpoint.uri="https://KEYCLOAK/auth/realms/myrealm/protocol/openid-connect/token" \
  oauth.client.id="kafka-client" \
  oauth.client.secret="xxxxxx";


This enables:

JWT access tokens for Kafka clients

Role-based authorization

Integration with LDAP via Keycloak federation

🚀 5. Optimizing Keycloak for Kafka

Kafka clusters may hit very high auth request volume.

Here’s how to tune Keycloak for large Kafka environments:

🔧 (A) Enable Keycloak Caching

Enable:

1. User Cache
2. Realm Cache
3. Authorization Cache

In:

Realm → Cache → Enable full caching

This dramatically reduces LDAP calls.

🔧 (B) Increase Token Lifetimes

Kafka clients often need:

Longer Access Token Lifetimes

Longer Refresh Token Lifetimes

Suggested:

Access Token Lifespan: 10-15 minutes
Refresh Token Lifespan: 1 day


Kafka clients are long-running and should not refresh too frequently.

🔧 (C) Stateless JWT Tokens

Prefer:

Signed JWT (RS256)

Do not use introspection for every call

JWT = no Keycloak call during message produce/consume
→ Major performance gain.

🔧 (D) Configure Keycloak to cache LDAP using periodic sync

Turn on:

✔ Import users
✔ Periodic sync (every 5–15 minutes)
✔ Cache LDAP groups

This eliminates live LDAP lookups during Kafka login.

🔧 (E) Horizontal scaling of Keycloak

For large Kafka deployments:

3–5 Keycloak pods minimum

Backed by:

HA PostgreSQL

Infinispan cache

Load balancer with sticky sessions disabled (stateless JWT)

🔧 (F) Use WildFly/Quarkus Keycloak optimizations

If using Keycloak.X (Quarkus):

Quarkus is extremely fast

Lower CPU usage

Faster startup

Better TLS performance

More efficient token service

🧩 6. Recommended Architecture
Kafka + Keycloak + LDAP Optimal Setup
         LDAP
          |
   +-------------+
   |  Keycloak   |
   | (Federation)|
   +-------------+
          |
     OAuth2/JWT
          |
    +-----------+
    |  Kafka    |
    | (OAuth2)  |
    +-----------+
          |
     Producers / Consumers

Why best?

All LDAP load absorbed by Keycloak

Kafka gets only JWT → no LDAP lookups

Easy RBAC

Scalable

Secure

Standardized

🏁 7. Summary
✔ Can Kafka connect to LDAP directly?

Yes, via plugins — but not recommended.

✔ Should you use Keycloak?

Yes if:

You want OAuth2/OIDC

You want tokens instead of passwords

You want LDAP federation

You want RBAC & auditable authentication

✔ How to optimize Keycloak for Kafka?

Enable caching

Use JWT access tokens

Increase token TTL

Periodic LDAP sync

Horizontal scaling

Keycloak.X (Quarkus) + distributed Infinispan cache

Next steps to provide:

✅ Strimzi example YAMLs for OAuth2 + Keycloak
✅ Keycloak client config for Kafka broker
✅ Kafka JAAS files for producers/consumers
✅ Helm chart integration
==================================================

1) Quick architecture (reminder)

Keycloak federates users from LDAP and issues OAuth2/OIDC JWTs. Kafka brokers validate those tokens (OAuthBearer). This avoids live LDAP binds on every Kafka connection — Keycloak (with caching and user import/sync) handles LDAP load.

2) Strimzi / Kafka: broker -> Keycloak (OAuth) snippet

Below is the minimal relevant part of a Strimzi Kafka custom resource that configures SASL/OAUTHBEARER for brokers and uses the Strimzi OAuth libraries (the Strimzi OAuth client/validator is the recommended, maintained option). Adapt realm/URLs/secrets to your env. See Strimzi docs for full CR fields. 
GitHub
+1

apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: my-cluster
spec:
  kafka:
    version: 3.6.0
    replicas: 3
    listeners:
      - name: plain-oauth
        port: 9094
        type: internal
        tls: false
        authentication:
          type: oauth
          oauth:
            tokenEndpointUri: "https://keycloak.my.svc/auth/realms/myrealm/protocol/openid-connect/token"
            clientId: "kafka-broker"
            clientSecret:
              secretName: kafka-broker-secret
              key: client-secret
            jwksEndpointUri: "https://keycloak.my.svc/auth/realms/myrealm/protocol/openid-connect/certs"
            # optional: disable TLS hostname verification, set to false for prod only when needed
            disableTlsHostnameVerification: false
            # optional: cache settings (Strimzi supports tuning)
            maxClockSkewSeconds: 60
    config:
      listeners:
        - name: plain-oauth
          sasl:
            mechanism: OAUTHBEARER


Notes: Strimzi provides strimzi-kafka-oauth helper libs (login/validator handlers). Use the Strimzi images or include the oauth jars in your Kafka image. 

3) Kafka broker (non-Strimzi) — core properties

If you run Kafka manually (not Strimzi), these are the broker-side properties you’ll need to set to accept OAUTHBEARER (example names vary by Kafka version):

listeners=SASL_PLAINTEXT://0.0.0.0:9094
listener.name.sasl_plaintext.oauthbearer.sasl.enabled.mechanisms=OAUTHBEARER
sasl.enabled.mechanisms=OAUTHBEARER
sasl.mechanism.inter.broker.protocol=OAUTHBEARER

# Callback handler class provided by Strimzi/Strimzi OAuth client
sasl.login.callback.handler.class=io.strimzi.kafka.oauth.server.OAuthAuthenticateCallbackHandler
# Or for newer Kafka + strimzi oauth client: io.strimzi.kafka.oauth.server.JaasServerOauthLoginCal

4) Client (producer/consumer) JAAS / properties (client_credentials flow)

Clients (non-browser service apps) commonly use client_credentials to get tokens from Keycloak. Use the Strimzi JaasClientOauthLoginCallbackHandler or the Kafka OAuth login module. 
## Example client.properties:
security.protocol=SASL_PLAINTEXT
sasl.mechanism=OAUTHBEARER

# If using Kafka's OAuthBearerLoginModule with Strimzi callback handler
sasl.jaas.config=org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required \
  oauth.token.endpoint.uri="https://keycloak.my.svc/auth/realms/myrealm/protocol/openid-connect/token" \
  oauth.client.id="kafka-producer" \
  oauth.client.secret="producer-secret";
  
# Or if using callback handler class:
sasl.login.callback.handler.class=io.strimzi.kafka.oauth.client.JaasClientOauthLoginCallbackHandler
## For client libraries you may also inject a static token (for testing) or implement a token refresher for long-running clients. Examples and helpers are in Strimzi and various community repos

5) Keycloak: minimal client setup (in Realm UI)

Create two clients in the realm:

kafka-broker (confidential) — used by brokers for inter-broker auth and broker→Keycloak interactions

Client ID: kafka-broker

Access Type: Confidential

Service Accounts Enabled: ON (if you use client_credentials)

Add a client secret (store in Kubernetes secret)

kafka-producer / kafka-consumer (confidential) — used by producers/consumers (or use a single kafka-client with scopes)

Client ID: kafka-producer

Access Type: Confidential

Service Accounts Enabled: ON

Keycloak token URL (to use in configs):
https://<keycloak-host>/auth/realms/<realm>/protocol/openid-connect/token (Keycloak docs). 
Keycloak
+1

Important mappers:

Add an audience mapper so tokens contain aud=kafka-broker or the audience your broker expects.

Map preferred_username or sub into the claims used for ACLs/authorization.

Optionally add roles or groups claims if you will use them for topic-level authorization.

6) LDAP federation in Keycloak (brief)

In Keycloak Admin Console → User Federation → Add provider ldap and configure:

LDAP URL, Bind DN, Bind Credential (service account)

Enable Import Users (so Keycloak caches/syncs LDAP users locally)

Set Periodic Full Sync and Changed Users Sync intervals as appropriate

Recommendation: enable Import Users + periodic sync (5–15 minutes) so Kafka connections validate against local Keycloak database / cache rather than hitting LDAP for every token request. This reduces LDAP load dramatically. 
Keycloak

7) Token strategy & performance tips (production checklist)

These are the high-impact settings I use for Kafka+Keycloak:

Stateless JWT validation — prefer JWKS / RS256-signed tokens so brokers can validate tokens locally (no introspection) when possible. JWT + JWKS = no Keycloak call per Kafka message. 
Keycloak
+1

Longer access token TTL for clients — e.g. 10–15 min access tokens, refresh tokens 12–24 hours (clients are long-lived). Avoid very short lifetimes that cause frequent refreshes.

Enable Keycloak user cache & realm cache — reduces DB/LDAP lookups; enable Infinispan-backed caching for cluster mode.

Import LDAP users into Keycloak + scheduled sync (5–15 min).

Horizontal scale Keycloak — run multiple Keycloak pods behind LB; use HA DB and Infinispan if needed. Keycloak.X (Quarkus) performs better and is preferred for high scale. 
Keycloak
+1

Use client_credentials flow for service clients (producers/consumers) to avoid interactive flows.

Audit & logging — log token validation failures so you can trace auth issues (mis-mapped audience/exp/nbf etc.).

Use an authorization layer (OPA or custom authorizer) if you need topic-level dynamic policies; Keycloak alone is authentication + user/role claims — Kafka still needs ACL enforcement mapping. See next point.

8) Authorization / ACLs

OAuth gives you identity and claims. Kafka still needs authorization (ACLs). Options:

Use Kafka ACLs (mapped from Keycloak groups/roles via automation).

Use a policy engine like OPA that consumes tokens/claims and enforces fine-grained topic-level rules. (Confluent and community writeups show OPA + Keycloak patterns.) 
Raft | Operationalize Data & Agentic AI

Confluent Platform historically included LDAP/authorizer integrations; with OIDC you usually automate ACL creation from Keycloak groups or use an external policy layer. 
Raft | Operationalize Data & Agentic AI

9) Helpful examples & repos (copy-paste friendly)

Strimzi blog: Kafka authentication using OAuth 2.0. (good conceptual + Strimzi instructions). 
strimzi.io

Strimzi OAuth GitHub (libraries used for client/server handlers). 
GitHub

Example repo showing Kafka + Keycloak OAuth configs (community repo). 
GitHub

Keycloak docs — token endpoint / OIDC basics. 
Keycloak

10) Short troubleshooting checklist (if things fail)

Verify token endpoint URL + realm path (/auth/realms/<realm>/protocol/openid-connect/token). 
Keycloak

Ensure aud claim in token includes the expected audience (broker or client).

Check broker logs for OAuth callback handler errors (classpath, jar missing). If using custom images, ensure strimzi-kafka-oauth jars are present. 
GitHub

Confirm Keycloak client secret is correct (K8s secret mounted where Strimzi expects).

For JWKS-based validation, ensure broker can access /.well-known/jwks.json or Keycloak certs URL.

If tokens are being introspected, check introspection endpoint auth and rate limits.

11) Generate next:
A. Full Strimzi Kafka CR + Kubernetes Secret + ServiceAccount + Keycloak realm JSON you can kcadm import.

B. Docker-compose / VM example showing Kafka (vanilla), Keycloak, and a producer using client_credentials (quick local POC).

C. Helm/values fragment for Strimzi + Keycloak + Ingress + secrets.

D. Full Keycloak realm export JSON with clients/roles/mappers tuned for Kafka (so you can import into your Keycloak).