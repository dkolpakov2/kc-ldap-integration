1) (Easiest) create a static Kubernetes Secret from a Vault value

Use this if you want a one-time copy from Vault into Kubernetes (not automatic sync).

Read the secret from Vault (example CLI):

# write LDAP credentials into Vault (one-time)
vault kv put secret/ldap username="cn=ldapuser,dc=example,dc=com" password="S3cr3t!"
# read value (optional)
vault kv get -format=json secret/ldap | jq -r '.data.data.password'


Create Kubernetes Secret (command):

# create k8s secret directly from literal (avoid exposing in shell history in production)
kubectl create secret generic ldap-creds \
  --from-literal=username='cn=ldapuser,dc=example,dc=com' \
  --from-literal=password='S3cr3t!' \
  -n default


Or a declarative YAML (vaultSecrets.yaml) you can kubectl apply -f vaultSecrets.yaml:

# vaultSecrets.yaml (static k8s Secret)
apiVersion: v1
kind: Secret
metadata:
  name: ldap-creds
  namespace: default
type: Opaque
stringData:
  username: "cn=ldapuser,dc=example,dc=com"
  password: "S3cr3t!"


Pros: simple. Cons: secret is copied and not synced; you must rotate/update it manually.

2) (Recommended for dynamic retrieval) use Vault Agent Injector annotations on your Pod/Deployment

Vault Agent Injector lets a pod automatically fetch the secret from Vault at start (and can refresh). This avoids storing the password in K8s Secrets.

Vault side (policy & role)

Example policy and Kubernetes-auth role you must create in Vault (run with Vault CLI / root token or admin access):

# policy to allow read of the key
cat > ldap-policy.hcl <<EOF
path "secret/data/ldap" {
  capabilities = ["read"]
}
EOF

vault policy write ldap-policy ldap-policy.hcl

# create k8s auth role which binds to a k8s ServiceAccount name+namespace
vault write auth/kubernetes/role/ldap-role \
  bound_service_account_names="ldap-app-sa" \
  bound_service_account_namespaces="default" \
  policies="ldap-policy" \
  ttl="1h"


(Ensure you configured auth/kubernetes on Vault with your cluster's JWT CA and token reviewer; see Vault docs for Kubernetes auth setup.)

Kubernetes side — Deployment YAML (vaultSecrets.yaml)

This example instructs the injector to place the LDAP password into a file inside the pod (/vault/secrets/ldap-password) from secret/data/ldap key password:

# vaultSecrets.yaml (Deployment annotated for Vault Agent Injector)
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ldap-app-sa
  namespace: default

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ldap-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ldap-app
  template:
    metadata:
      labels:
        app: ldap-app
      annotations:
        # enable vault agent injector
        vault.hashicorp.com/agent-inject: "true"
        # which Vault role (created in vault CLI step above)
        vault.hashicorp.com/role: "ldap-role"
        # where to mount the injected files inside the pod (optional)
        vault.hashicorp.com/agent-inject-token-request: "true"
        # request the secret at path secret/data/ldap and call it "ldap"
        # format: vault.hashicorp.com/agent-inject-secret-<id>: <vault-path>#<key>
        vault.hashicorp.com/agent-inject-secret-ldap: "secret/data/ldap#password"
        # write a template file that contains only the password
        vault.hashicorp.com/agent-inject-template-ldap: |
          {{- with secret "secret/data/ldap" -}}
          {{ .Data.data.password }}
          {{- end }}
    spec:
      serviceAccountName: ldap-app-sa
      containers:
        - name: ldap-app
          image: alpine:3.18
          command: ["/bin/sh","-c"]
          args:
            - |
              echo "Secret file contents (for demo):"
              cat /vault/secrets/ldap     # injected secret file
              sleep 3600
          volumeMounts:
            - name: vault-secret
              mountPath: /vault/secrets
      volumes:
        - name: vault-secret
          emptyDir: {}


Notes:

The injector will mount the template result into /vault/secrets/ldap (file name derived from annotation key). You can read it from your app or load it into env at container start.

The annotation vault.hashicorp.com/agent-inject-secret-ldap points to the Vault KV v2 path secret/data/ldap and the #password key inside that data object.

Make sure Vault injector sidecar is installed in your cluster (the vault-helm chart or otherwise).

Pros: dynamic, no k8s secret stored, automatic refresh available. Cons: requires Vault Agent Injector installed and Vault Kubernetes auth configured.

3) (If you run External Secrets operator) use Kubernetes ExternalSecret CRD (External Secrets Operator)

If you have [external-secrets] (Kubernetes External Secrets / external-secrets.io) installed and configured to talk to Vault, you can declare an ExternalSecret that maps Vault KV values into a Kubernetes Secret automatically.

Example vaultSecrets.yaml (ExternalSecret -> creates a k8s secret):

# vaultSecrets.yaml (ExternalSecret for External Secrets Operator)
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: ldap-external-secret
  namespace: default
spec:
  refreshInterval: "1h"                # how often to refresh
  secretStoreRef:
    name: vault-backend                # preconfigured SecretStore that points to Vault
    kind: SecretStore
  target:
    name: ldap-creds                   # created Kubernetes Secret name
    creationPolicy: Owner
  data:
    - secretKey: username
      remoteRef:
        key: secret/data/ldap
        property: username
    - secretKey: password
      remoteRef:
        key: secret/data/ldap
        property: password


You must preconfigure a SecretStore or ClusterSecretStore that points to your Vault instance and credentials.

Pros: creates/maintains a K8s Secret automatically from Vault. Cons: requires installing ExternalSecrets operator and secret store config.

Quick checklist / troubleshooting

Vault path: remember KV v2 uses secret/data/<path> for reads; template strings use secret "<path>" syntaxes in injector templates.

Vault Kubernetes auth must be configured (JWT reviewer, Kubernetes auth mounted) and your service account must be allowed by the Vault role.

If injector isn’t injecting: check pod annotations, events (kubectl describe pod), and injector logs (namespace where injector runs).

Permissions: create a minimal Vault policy that only allows read on secret/data/ldap.

Do not hardcode plaintext secrets in manifest repos. Use CI secrets or Vault CLI to write secrets to Vault securely.