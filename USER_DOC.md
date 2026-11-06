# User documentation

This guide explains how to use the Inception stack day to day, without needing to know how it is built.

## 1. What the stack provides

| Service | What it does for you |
|---|---|
| **Website** (nginx) | Serves the WordPress site over HTTPS at `https://crmorale.42.fr`. It is the only door into the system: port 443 only. |
| **WordPress** | The website and its administration panel. |
| **Database** (MariaDB) | Stores posts, pages, users and settings. It is not reachable from outside. |

Data is kept on the VM in `/home/crmorale/data/`, so it survives restarts.

## 2. Start and stop

Run these from the root of the project:

| Action | Command |
|---|---|
| Build (if needed) and start everything | `make` |
| Stop the containers (data is kept) | `make down` |
| Start again after a stop | `make` |

The first start takes a few minutes: images are built and WordPress is downloaded and installed. Later starts take a few seconds.

## 3. Access the website

1. Make sure the domain points to the VM. This line must be in `/etc/hosts`:
   ```
   127.0.0.1 crmorale.42.fr
   ```
2. Open **https://crmorale.42.fr** in a browser.
3. The certificate is self-signed, so the browser shows a security warning. Accept it to continue: *Advanced → Continue*.

**Administration panel:** https://crmorale.42.fr/wp-admin

Two WordPress accounts exist:

| Account | Role | User name set in |
|---|---|---|
| Administrator | Full control of the site | `WP_ADMIN_USER` in `srcs/.env` |
| Second user | Author: can write and publish posts | `WP_USER` in `srcs/.env` |

## 4. Credentials

Passwords are **never** stored in `.env` or in the git repository. They live in the `secrets/` folder at the root of the project:

| File | Contains |
|---|---|
| `secrets/credentials.txt` | WordPress passwords: `WP_ADMIN_PASSWORD=...` and `WP_USER_PASSWORD=...` |
| `secrets/db_password.txt` | Password of the database user used by WordPress |
| `secrets/db_root_password.txt` | Password of the MariaDB `root` account |

User names and emails are in `srcs/.env`.

**Changing a password.** The secret files are only read when the site is installed for the first time. To change a WordPress password afterwards, use the panel (*Users → Profile*), or reset everything with `make fclean` and then `make`. This deletes all site data.

## 5. Check that everything is running

```sh
docker ps
```
The three containers `nginx`, `wordpress` and `mariadb` must be listed with status `Up`.

Other checks:

| Check | Command | Expected result |
|---|---|---|
| Logs of a service | `docker logs nginx` (or `wordpress`, `mariadb`) | No errors; last line says the service started |
| HTTPS answers | `curl -k -I https://crmorale.42.fr` | `HTTP/1.1 200 OK` (or a redirect) |
| Plain HTTP is closed | `curl -I http://crmorale.42.fr` | Connection refused |
| Old TLS refused | `openssl s_client -connect crmorale.42.fr:443 -tls1_1` | Handshake failure |
| Database is alive | `docker exec mariadb mariadb-admin ping -u root -p` (enter the root password) | `mysqld is alive` |

If a container crashes it restarts automatically. `docker ps` shows it back as `Up` after a few seconds.
