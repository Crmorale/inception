FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
        nginx \
        openssl \
    && rm -rf /var/lib/apt/lists/*

# Quitamos el sitio por defecto de Debian (escucha en el 80)
# y forzamos TLS 1.2/1.3 también en la configuración global.
RUN rm -f /etc/nginx/sites-enabled/default \
    && sed -i 's/^\s*ssl_protocols.*/\tssl_protocols TLSv1.2 TLSv1.3;/' /etc/nginx/nginx.conf \
    && mkdir -p /etc/nginx/ssl

COPY conf/inception.conf /etc/nginx/conf.d/inception.conf
COPY tools/init.sh /usr/local/bin/init.sh

RUN chmod +x /usr/local/bin/init.sh

EXPOSE 443

ENTRYPOINT ["/usr/local/bin/init.sh"]
