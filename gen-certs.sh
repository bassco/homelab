#!/bin/bash
# gen-cert.sh - Create a local CA and sign service certs for Nginx
# Usage:
#   ./gen-cert.sh ca                 # generate root CA
#   ./gen-cert.sh cert <service>     # generate cert for service (e.g. homeassistant.local)

set -e

CA_DIR="./ca"
CERTS_DIR="./nginx/certs"

mkdir -p "$CA_DIR" "$CERTS_DIR"

function create_ca() {
  if [[ -f "$CA_DIR/myCA.key" ]]; then
    echo "CA already exists in $CA_DIR"
    return
  fi

  echo "Generating new Certificate Authority..."
  openssl genrsa -out "$CA_DIR/myCA.key" 4096
  openssl req -x509 -new -nodes -key "$CA_DIR/myCA.key" -sha256 -days 3650 \
    -out "$CA_DIR/myCA.crt" \
    -subj "/C=US/ST=Local/L=LAN/O=MyHomeCA/CN=MyHomeCA"

  echo "✅ CA created: $CA_DIR/myCA.crt (import this into your OS/browser trust store)"
}

function create_cert() {
  SERVICE="$1"
  if [[ -z "$SERVICE" ]]; then
    echo "❌ Missing service name (e.g. ./gen-cert.sh cert homeassistant.local)"
    exit 1
  fi

  KEY="$CERTS_DIR/$SERVICE.key"
  CSR="$CERTS_DIR/$SERVICE.csr"
  CRT="$CERTS_DIR/$SERVICE.crt"
  EXT="$CERTS_DIR/$SERVICE.ext"

  echo "Generating cert for $SERVICE ..."

  # Private key
  openssl genrsa -out "$KEY" 2048

  # CSR
  openssl req -new -key "$KEY" -out "$CSR" \
    -subj "/C=US/ST=Local/L=LAN/O=Home/CN=$SERVICE"

  # Extensions for SAN
  cat > "$EXT" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $SERVICE
EOF

  # Sign with CA
  openssl x509 -req -in "$CSR" \
    -CA "$CA_DIR/myCA.crt" -CAkey "$CA_DIR/myCA.key" -CAcreateserial \
    -out "$CRT" -days 825 -sha256 -extfile "$EXT"

  echo "✅ Certificate issued: $CRT"
  echo "   Key: $KEY"
}

case "$1" in
  ca)
    create_ca
    ;;
  cert)
    create_cert "$2"
    ;;
  *)
    echo "Usage:"
    echo "  $0 ca                 # create root CA"
    echo "  $0 cert <service>     # issue cert for service (e.g. homeassistant.local)"
    exit 1
    ;;
esac

