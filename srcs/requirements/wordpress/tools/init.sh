#!/bin/sh
set -e

# --- 1. Leer contraseñas desde los secrets (nunca desde el .env) -------------
DB_PASSWORD="$(cat /run/secrets/db_password)"
WP_ADMIN_PASSWORD="$(grep '^WP_ADMIN_PASSWORD=' /run/secrets/credentials | cut -d= -f2-)"
WP_USER_PASSWORD="$(grep '^WP_USER_PASSWORD=' /run/secrets/credentials | cut -d= -f2-)"

if [ -z "$WP_ADMIN_PASSWORD" ] || [ -z "$WP_USER_PASSWORD" ]; then
    echo "[wordpress] ERROR: faltan WP_ADMIN_PASSWORD o WP_USER_PASSWORD en credentials.txt" >&2
    exit 1
fi

# --- 2. Regla del subject: el admin no puede llamarse admin/administrator -----
case "$WP_ADMIN_USER" in
    *[Aa]dmin*|*[Aa]dministrator*)
        echo "[wordpress] ERROR: WP_ADMIN_USER no puede contener 'admin'" >&2
        exit 1
        ;;
esac

# --- 3. Esperar a que MariaDB acepte conexiones (bucle con límite, no infinito)
export MYSQL_PWD="$DB_PASSWORD"
tries=0
until mariadb -h "$MYSQL_HOST" -u "$MYSQL_USER" -e "SELECT 1" "$MYSQL_DATABASE" >/dev/null 2>&1; do
    tries=$((tries + 1))
    if [ "$tries" -ge 30 ]; then
        echo "[wordpress] ERROR: MariaDB no responde tras 30 intentos" >&2
        exit 1
    fi
    echo "[wordpress] Esperando a MariaDB... ($tries/30)"
    sleep 1
done
unset MYSQL_PWD

# --- 4. Primera vez: descargar, configurar e instalar WordPress --------------
if [ ! -f wp-load.php ]; then
    echo "[wordpress] Descargando WordPress..."
    wp core download --allow-root
fi

if [ ! -f wp-config.php ]; then
    echo "[wordpress] Creando wp-config.php..."
    wp config create --allow-root \
        --dbname="$MYSQL_DATABASE" \
        --dbuser="$MYSQL_USER" \
        --dbpass="$DB_PASSWORD" \
        --dbhost="$MYSQL_HOST:3306"
fi

if ! wp core is-installed --allow-root; then
    echo "[wordpress] Instalando WordPress..."
    wp core install --allow-root \
        --url="https://$DOMAIN_NAME" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email

    wp user create "$WP_USER" "$WP_USER_EMAIL" --allow-root \
        --role=author \
        --user_pass="$WP_USER_PASSWORD"
fi

chown -R www-data:www-data /var/www/html

# --- 5. Arrancar php-fpm en primer plano como PID 1 --------------------------
# -F = foreground: php-fpm no se convierte en demonio, así el contenedor
# vive exactamente lo que viva php-fpm (sin tail -f ni sleep infinity).
echo "[wordpress] Arrancando php-fpm"
exec php-fpm8.2 -F
