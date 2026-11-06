# Developer documentation

## 1. Set up the environment from scratch

### Prerequisites

- A Linux virtual machine (Debian or Ubuntu recommended).
- Docker Engine and the Docker Compose plugin (`docker compose version` must work).
- `make`, `git`, and `openssl` (optional, for testing TLS).
- Your user in the `docker` group (`sudo usermod -aG docker $USER`, then log in again), or run the commands with `sudo`.
- `/etc/hosts` entry: `127.0.0.1 crmorale.42.fr`.

### Project layout

```
.
├── Makefile
├── secrets/                     # NOT tracked by git
│   ├── credentials.txt
│   ├── db_password.txt
│   └── db_root_password.txt
└── srcs/
    ├── .env                     # non-secret configuration
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/   { Dockerfile, conf/50-server.cnf, tools/init.sh }
        ├── wordpress/ { Dockerfile, conf/www.conf,      tools/init.sh }
        └── nginx/     { Dockerfile, conf/inception.conf, tools/init.sh }
```

### Configuration files

**`srcs/.env`**: non-confidential settings, read by Compose and passed into the containers:

| Variable | Used by | Meaning |
|---|---|---|
| `LOGIN` | Makefile, compose | 42 login; builds `/home/$LOGIN/data` |
| `DOMAIN_NAME` | nginx, wordpress | Site domain (`crmorale.42.fr`) |
| `MYSQL_DATABASE`, `MYSQL_USER` | mariadb, wordpress | Database and user created for WordPress |
| `MYSQL_HOST` | wordpress | Host name of the database service (`mariadb`) |
| `WP_TITLE` | wordpress | Site title |
| `WP_ADMIN_USER`, `WP_ADMIN_EMAIL` | wordpress | Administrator account. The name must not contain "admin" |
| `WP_USER`, `WP_USER_EMAIL` | wordpress | Second account (role: author) |

**`secrets/`**: create the three files by hand. The Makefile refuses to start if one is missing:

```sh
mkdir -p secrets
printf '%s' 'a-strong-db-password'  > secrets/db_password.txt
printf '%s' 'a-strong-root-password' > secrets/db_root_password.txt
printf 'WP_ADMIN_PASSWORD=%s\nWP_USER_PASSWORD=%s\n' 'admin-pass' 'user-pass' > secrets/credentials.txt
```

Compose mounts them read-only at `/run/secrets/<name>` in the containers that declare them: `mariadb` gets `db_password` and `db_root_password`, and `wordpress` gets `db_password` and `credentials`.

## 2. Build and launch

```sh
make
```

The Makefile reads `srcs/.env`, checks that the secrets exist and restricts their permissions, creates `/home/$LOGIN/data/mariadb` and `/home/$LOGIN/data/wordpress`, and then runs:

```sh
docker compose -f srcs/docker-compose.yml up -d --build
```

Compose creates the `inception` network and the two volumes, builds the three images (`mariadb:inception`, `wordpress:inception`, `nginx:inception`) and starts the containers in dependency order: mariadb → wordpress → nginx.

What each entrypoint does on first start:

| Container | `tools/init.sh` |
|---|---|
| mariadb | Initialises the data directory, creates the database and `MYSQL_USER@'%'`, sets the root password, then `exec mysqld` |
| wordpress | Waits for MariaDB (max 30 tries), downloads WordPress, creates `wp-config.php`, installs the site, creates both users, then `exec php-fpm8.2 -F` |
| nginx | Generates a self-signed certificate, sets `server_name`, runs `nginx -t`, then `exec nginx -g 'daemon off;'` |

On later starts every one-time step is skipped, and only the daemon is launched.

## 3. Managing containers and volumes

### Makefile targets

| Target | Effect |
|---|---|
| `make` / `make all` | Build images if needed and start the stack |
| `make down` | Stop and remove containers (volumes and data kept) |
| `make clean` | `down` plus remove the project images |
| `make fclean` | `clean` plus remove volumes, network and `/home/$LOGIN/data` (**all site data lost**) |
| `make re` | `fclean` then `all` |

### Useful Docker commands

```sh
# State
docker ps                              # running containers
docker compose -f srcs/docker-compose.yml ps
docker images                          # mariadb/wordpress/nginx with tag "inception"
docker volume ls                       # mariadb_data, wordpress_data
docker network ls                      # inception

# Logs
docker logs -f wordpress
docker compose -f srcs/docker-compose.yml logs -f

# Shell inside a container
docker exec -it mariadb bash
docker exec -it wordpress bash
docker exec -it nginx bash

# Database
docker exec -it mariadb mariadb -u root -p
#   SHOW DATABASES;  USE wordpress;  SELECT user_login FROM wp_users;

# WordPress from the command line
docker exec -it wordpress wp user list --allow-root

# Rebuild one service after changing its files
docker compose -f srcs/docker-compose.yml up -d --build wordpress

# Inspect a volume
docker volume inspect wordpress_data
```

## 4. Where the data lives and how it persists

| Volume | Mounted at (container) | Stored at (host) | Contents |
|---|---|---|---|
| `mariadb_data` | `/var/lib/mysql` in `mariadb` | `/home/crmorale/data/mariadb` | Database files |
| `wordpress_data` | `/var/www/html` in `wordpress` and `nginx` | `/home/crmorale/data/wordpress` | WordPress core, themes, plugins, uploads, `wp-config.php` |

Both are **named volumes** using the `local` driver, with `driver_opts` that place their data in the host folders above.

Persistence:

- `make down`, a crash or a VM reboot **does not** lose data. Containers are recreated, the entrypoints see that setup is already done, and they just start the daemons.
- Only `make fclean`, or deleting `/home/crmorale/data` by hand, erases the data. The next `make` installs everything from scratch.
- The TLS certificate is not on a volume. It is regenerated whenever the nginx container is recreated.
