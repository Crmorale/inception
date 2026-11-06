*This project has been created as part of the 42 curriculum by crmorale.*

# Inception

## Description

Inception is a system administration project whose goal is to build a small but complete web infrastructure using **Docker** and **Docker Compose**, inside a virtual machine.

The stack serves a WordPress website over HTTPS and is made of three services, each running in its own container and built from a Dockerfile written for this project (no ready-made application images are pulled):

| Service | Role | Listens on |
|---|---|---|
| **nginx** | Only entry point of the infrastructure. Terminates TLS (TLSv1.2 / TLSv1.3 only) and forwards PHP requests to WordPress. | `443` (published to the host) |
| **wordpress** | WordPress + php-fpm. Executes PHP; it has no web server of its own. | `9000` (internal network only) |
| **mariadb** | Database holding all WordPress content. | `3306` (internal network only) |

Request path: `browser → nginx:443 (TLS) → wordpress:9000 (FastCGI) → mariadb:3306`.

## Instructions

### Requirements

- A Linux virtual machine with Docker Engine, the Docker Compose plugin and `make`.
- The domain `crmorale.42.fr` pointing to the VM: add `127.0.0.1 crmorale.42.fr` to `/etc/hosts`.

### Configuration

1. Edit `srcs/.env` (non-secret settings: login, domain, database name, WordPress user names and emails).
2. Create the three secret files (they are ignored by git):

   ```
   secrets/db_password.txt        # password of the WordPress database user
   secrets/db_root_password.txt   # MariaDB root password
   secrets/credentials.txt        # WordPress user passwords, one per line:
                                  #   WP_ADMIN_PASSWORD=...
                                  #   WP_USER_PASSWORD=...
   ```

### Run

```sh
make          # creates /home/crmorale/data/*, builds the images and starts the stack
```

Then open `https://crmorale.42.fr` (the certificate is self-signed, so the browser will show a warning the first time). The admin panel is at `https://crmorale.42.fr/wp-admin`.

See [USER_DOC.md](USER_DOC.md) for day-to-day usage and [DEV_DOC.md](DEV_DOC.md) for developer details.

## Project description

### Use of Docker and sources included

Each service has its own folder under `srcs/requirements/` with the same layout:

```
<service>/
├── Dockerfile      # how the image is built
├── conf/           # configuration files copied into the image
└── tools/init.sh   # entrypoint: one-time setup, then `exec` of the real daemon
```

- `srcs/docker-compose.yml` defines the three services, the `inception` network, the two named volumes and the three secrets.
- `srcs/.env` holds non-confidential configuration.
- `secrets/` holds passwords; it is not tracked by git.
- The `Makefile` prepares the host data folders and drives Docker Compose.

### Main design choices

- **Base image: `debian:bookworm`**, the penultimate stable Debian release, as required. Debian was chosen for its well-known packages (`mariadb-server`, `php8.2-fpm`, `nginx`).
- **Each daemon runs as PID 1 in the foreground.** Every `init.sh` ends with `exec` (`exec mysqld`, `exec php-fpm8.2 -F`, `exec nginx -g 'daemon off;'`). The shell is replaced by the service, which therefore receives signals such as `SIGTERM` directly and stops cleanly. No `tail -f`, `sleep infinity` or `while true` is used.
- **Idempotent entrypoints.** Each script checks whether its setup was already done (database directory exists, `wp-config.php` exists, WordPress is installed, certificate exists). The first start initialises everything; later starts only launch the daemon, so data on the volumes is never overwritten.
- **WordPress is installed with `wp-cli`.** The script waits (with a bounded number of retries) until MariaDB accepts the WordPress user, then downloads WordPress, writes `wp-config.php`, installs the site, and creates two users: an administrator, whose name may not contain "admin", and an author.
- **php-fpm listens on TCP port 9000** instead of its default Unix socket, because a socket cannot be shared between two containers.
- **The TLS certificate is self-signed** and generated with `openssl` the first time the nginx container starts. `ssl_protocols TLSv1.2 TLSv1.3;` is set both globally and in the server block.
- **`restart: always`** on every service, so containers come back automatically after a crash.

### Virtual Machines vs Docker

A **virtual machine** emulates a complete computer: it runs its own kernel on top of a hypervisor and boots a whole operating system. It provides strong isolation but is heavy, since it needs gigabytes of disk, its own RAM and a boot time of minutes.

A **Docker container** is an isolated process running on the host's kernel. Namespaces separate it, and cgroups limit its resources. It only packages the application and its dependencies, so it starts in seconds and uses much less disk and memory. The trade-off is weaker isolation, because every container shares the host kernel.

In this project both are used together. The VM provides a clean, disposable environment, and Docker splits the services inside it.

### Secrets vs Environment Variables

**Environment variables** (here, from `srcs/.env`) are convenient for configuration, but they are visible to anything that can inspect the container (`docker inspect`, `/proc/<pid>/environ`, logs, child processes). They are suitable for non-confidential data such as the domain name or the database name.

**Docker secrets** are files mounted read-only at `/run/secrets/<name>` inside only the containers that declare them. They do not show up in `docker inspect` or in the environment, and the source files live outside the image and outside git. All passwords in this project are passed this way; no password appears in a Dockerfile, in `.env` or in the repository.

### Docker Network vs Host Network

With **`network: host`** a container shares the host's network stack. Every port it opens is opened on the host, and there is no isolation between services. This is forbidden by the subject.

With a **user-defined bridge network** (`inception`), containers get their own private network. They reach each other by service name through Docker's internal DNS (`mariadb`, `wordpress`), and nothing is reachable from outside unless explicitly published. Here only nginx publishes a port (`443`). MariaDB and php-fpm are reachable only from inside the network.

### Docker Volumes vs Bind Mounts

A **bind mount** maps an arbitrary host path straight into a container. Docker does not manage it: it is tied to the host's directory layout, and it is not listed in `docker volume ls`.

A **named volume** is an object managed by Docker. It has a name, it can be listed, inspected and removed with `docker volume` commands, and it is declared once and shared between services by name. The subject requires named volumes, stored under `/home/crmorale/data`. Both volumes (`mariadb_data`, `wordpress_data`) are therefore named volumes using the `local` driver, with `driver_opts` that place their data in `/home/crmorale/data/mariadb` and `/home/crmorale/data/wordpress`.

## Resources

- Docker documentation: https://docs.docker.com/
- Dockerfile best practices: https://docs.docker.com/build/building/best-practices/
- Docker Compose file reference: https://docs.docker.com/reference/compose-file/
- Compose secrets: https://docs.docker.com/compose/how-tos/use-secrets/
- NGINX SSL module: https://nginx.org/en/docs/http/ngx_http_ssl_module.html
- NGINX and PHP-FPM (FastCGI): https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html
- MariaDB documentation: https://mariadb.com/kb/en/documentation/
- WP-CLI commands: https://developer.wordpress.org/cli/commands/
- PHP-FPM configuration: https://www.php.net/manual/en/install.fpm.configuration.php
- About PID 1 in containers: https://docs.docker.com/engine/containers/multi-service_container/

### Use of AI

An AI assistant (Claude) was used as a study and support tool during the project:

- **Understanding concepts**: explanations of Docker images vs containers, PID 1 and `exec`, Docker secrets, named volumes and the request flow between nginx, php-fpm and MariaDB.
- **Execution flow**: a step-by-step walkthrough of what happens from `make` to the running stack.
- **WordPress and NGINX services**: first drafts of the Dockerfiles, configuration files and entrypoint scripts, which were then reviewed, tested and adapted to the existing MariaDB service, `docker-compose.yml` and `.env`.
- **Documentation**: drafting of this README, `USER_DOC.md` and `DEV_DOC.md`.

All generated content was reviewed and tested in the virtual machine, and every part of the project can be explained during the defense.
