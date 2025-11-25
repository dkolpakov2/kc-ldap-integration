#!/usr/bin/env bash

# List of 10 URLs (edit as needed)
URLS=(
  "https://example.com"
  "https://google.com"
  "https://github.com"
  "https://cloudflare.com"
  "https://mozilla.org"
  "https://wikipedia.org"
  "https://amazon.com"
  "https://bing.com"
  "https://apple.com"
  "https://openai.com"
)

i=1

for URL in "${URLS[@]}"; do
  CERT_FILE="/tmp/ssl_cert_${i}.pem"

  echo "Fetching certificate for: $URL"
  echo "Saving to: $CERT_FILE"

  # Run curl in verbose mode and capture CERT block using sed
  curl --insecure --verbose "$URL" 2>&1 \
    | sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' > "$CERT_FILE"

  # Validate output
  if [ -s "$CERT_FILE" ]; then
    echo "OK: Certificate saved."
    export SSL_CERT_FILE="$CERT_FILE"
  else
    echo "ERROR: No certificate extracted."
  fi

  echo "SSL_CERT_FILE now points to $SSL_CERT_FILE"
  echo "---------------------------------------------"
  i=$((i+1))
done