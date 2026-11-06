#!/bin/bash
set -e

# Passwords come from Docker secrets, never from the image or .env
DB_PASSWORD="$(cat /run/secrets/db_password)"
DB_ROOT_PASSWORD="$(cat /run/secrets/db_root_password)"

# The volume may be mounted empty: make sure ownership is right
chown -R mysql:mysql /var/lib/mysql /run/mysqld

# 1) System tables (only if the volume is empty)
if [ ! -d /var/lib/mysql/mysql ]; then
    echo "[mariadb] Initializing data directory..."
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql > /dev/null
fi

# 2) Database + users (only the first time -> idempotent)
if [ ! -d "/var/lib/mysql/${MYSQL_DATABASE}" ]; then
    echo "[mariadb] Creating database '${MYSQL_DATABASE}' and user '${MYSQL_USER}'..."
    mysqld --user=mysql --bootstrap <<EOF
USE mysql;
FLUSH PRIVILEGES;
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF
else
    echo "[mariadb] Database already exists, skipping init."
fi

# 3) mysqld replaces this shell and becomes PID 1 (receives SIGTERM properly)
exec mysqld --user=mysql
