#!/bin/sh
# shellcheck disable=SC2181
mkdir -p /data/db
cp -n /db/sqlite.db /data/db/sqlite.db

#if [ -z "$SESSION_SECRET_KEY" ]; then
#    echo "SESSION_SECRET_KEY not found, generating random key..."
#    SESSION_SECRET_KEY=$(openssl rand -hex 32)
#    echo "Generated SESSION_SECRET_KEY: ${SESSION_SECRET_KEY:0:8}..."
#else
echo "Using existing SESSION_SECRET_KEY: ${SESSION_SECRET_KEY:0:8}..."
#fi

echo "SESSION_SECRET_KEY is set: ${SESSION_SECRET_KEY:0:8}..."

echo "Environment check:"
echo "DATABASE_URL: $DATABASE_URL"
echo "NODE_ENV: $NODE_ENV"
echo "SESSION_SECRET_KEY length: ${#SESSION_SECRET_KEY}"

# CA Certificate Configuration
if [ -n "$NODE_EXTRA_CA_CERTS" ] && [ -f "$NODE_EXTRA_CA_CERTS" ]; then
    echo "CA certificate found at $NODE_EXTRA_CA_CERTS"
    echo "CA certificates will be loaded into Node.js trusted store"
elif [ -n "$CA_CERT_PATH" ] && [ -f "$CA_CERT_PATH" ]; then
    echo "CA certificate found at $CA_CERT_PATH"
    export NODE_EXTRA_CA_CERTS="$CA_CERT_PATH"
    echo "CA certificates will be loaded into Node.js trusted store"
else
    if [ -n "$NODE_EXTRA_CA_CERTS" ] || [ -n "$CA_CERT_PATH" ]; then
        echo "Warning: CA certificate path specified but file not found"
    else
        echo "No custom CA certificates configured"
    fi
fi

#MODE="admin"

#for arg in "$@"; do
#  case "$arg" in
#    --mode=*)
#      MODE="${arg#*=}"
#      ;;
#    *)
#      echo "Unknown option: $arg"
#      exit 1
#      ;;
#  esac
#done

#if [ "$MODE" = "query" ]; then
#  RESTRICTED=true
#else
#  RESTRICTED=false
#fi

cat <<EOF > /app-root/_master_app/assets/_.js
Object.defineProperty(window, "restricted", {
  value: false,
  writable: false,
  configurable: false,
});
EOF

if [ -f "$SSL_CERT_PATH" ] && [ -f "$SSL_KEY_PATH" ]; then
    echo "SSL certificates found at $SSL_CERT_PATH and $SSL_KEY_PATH"

    mkdir -p /etc/nginx/ssl

    ln -sf "$SSL_CERT_PATH" /etc/nginx/ssl/cert.pem
    ln -sf "$SSL_KEY_PATH" /etc/nginx/ssl/key.pem

    nginx -t
    if [ $? -ne 0 ]; then
        echo "Nginx configuration test failed, check your SSL certificates"
        exit 1
    fi
else
    echo "No SSL certificates found, starting Nginx with HTTP only"
    sed -i 's/listen 443 ssl/#listen 443 ssl/g' /etc/nginx/nginx.conf
    sed -i 's/listen \[::\]:443 ssl/#listen \[::\]:443 ssl/g' /etc/nginx/nginx.conf
    sed -i 's/ssl_certificate/#ssl_certificate/g' /etc/nginx/nginx.conf
    sed -i 's/ssl_certificate_key/#ssl_certificate_key/g' /etc/nginx/nginx.conf
fi

echo "Starting Node.js application..."
echo "Final environment check before starting Node.js:"
echo "DATABASE_URL: $DATABASE_URL"
echo "SESSION_SECRET_KEY: ${SESSION_SECRET_KEY:0:8}..."
echo "NODE_EXTRA_CA_CERTS: $NODE_EXTRA_CA_CERTS"

export DATABASE_URL="$DATABASE_URL"
export SESSION_SECRET_KEY="$SESSION_SECRET_KEY"
export NODE_ENV="$NODE_ENV"
if [ -n "$NODE_EXTRA_CA_CERTS" ]; then
    export NODE_EXTRA_CA_CERTS="$NODE_EXTRA_CA_CERTS"
fi

node ./_backend_app/main.js &

echo "Starting Nginx..."
nginx -g "daemon off;"
