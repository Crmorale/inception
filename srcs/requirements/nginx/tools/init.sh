#!/bin/sh
set -e

# --- 1. Certificado autofirmado (solo si no existe) --------------------------
if [ ! -f /etc/nginx/ssl/inception.crt ]; then
    echo "[nginx] Generando certificado TLS para $DOMAIN_NAME"
    openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
        -keyout /etc/nginx/ssl/inception.key \
        -out    /etc/nginx/ssl/inception.crt \
        -subj "/C=ES/ST=Catalonia/L=Barcelona/O=42/CN=$DOMAIN_NAME"
fi

# --- 2. Poner el dominio real en la configuración ----------------------------
sed -i "s/DOMAIN_NAME_PLACEHOLDER/$DOMAIN_NAME/" /etc/nginx/conf.d/inception.conf

# --- 3. Comprobar la configuración antes de arrancar --------------------------
nginx -t

# --- 4. NGINX en primer plano como PID 1 -------------------------------------
# 'daemon off' es la forma oficial de que nginx no se vaya a segundo plano.
echo "[nginx] Arrancando nginx en el puerto 443"
exec nginx -g 'daemon off;'
