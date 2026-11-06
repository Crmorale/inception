# Inception — Checklist antes de entregar

Lo marcado como **⚠ NO COMPROBADO** se ha escrito sin poder arrancarlo. Hay que verificarlo en la VM.
Este archivo está en `.gitignore` y no se sube al repo.

---

## A. Archivos que aún no he visto (revisar tú)

- [ ] **Makefile**: debe tener las reglas `all`, `down`, `clean`, `fclean` y `re`, porque `DEV_DOC.md` y `USER_DOC.md` las nombran. Si alguna no existe o hace otra cosa, ajusta la tabla en esos dos archivos.
- [ ] **`fclean` borra `/home/crmorale/data`.** Esa carpeta es de root, porque la crea MariaDB/WordPress con otros UID. Puede necesitar `sudo rm -rf`. Pruébalo.
- [ ] **`conf/50-server.cnf` de MariaDB**: debe tener `bind-address = 0.0.0.0` y `port = 3306`. Si escucha en `127.0.0.1`, WordPress no conecta: verás "Esperando a MariaDB... (30/30)".
- [ ] **Dockerfile de MariaDB**: que haga `mkdir -p /run/mysqld`. Tu `init.sh` hace `chown` de esa ruta y con `set -e` fallaría si no existe.
- [ ] **`.gitignore`**: si ya tenías uno, no lo sobrescribas. Añade a mano las líneas del nuevo.

## B. Antes del primer `make`

- [ ] Cambiar las contraseñas `changeme_*` de `secrets/credentials.txt` por otras de verdad. Lo mismo con `db_password.txt` y `db_root_password.txt` si también son de prueba.
- [ ] `/etc/hosts` de la VM: `127.0.0.1 crmorale.42.fr`
- [ ] Empezar desde cero: `make fclean` (o `docker system prune -a` y borrar `/home/crmorale/data`).

## C. ⚠ NO COMPROBADO — al arrancar

- [ ] `make` termina sin errores y `docker ps` muestra los 3 contenedores `Up`.
- [ ] `docker logs wordpress` termina en `[wordpress] Arrancando php-fpm`.
- [ ] `docker logs nginx` muestra `syntax is ok` y `Arrancando nginx`.
- [ ] `https://crmorale.42.fr` carga WordPress (aceptando el aviso del certificado).
- [ ] `https://crmorale.42.fr/wp-admin`: entra con `jefe` / `WP_ADMIN_PASSWORD`.
- [ ] Entra también con `autor` / `WP_USER_PASSWORD`.
- [ ] `docker exec -it wordpress wp user list --allow-root` muestra 2 usuarios: `jefe` (administrator) y `autor` (author).
- [ ] La web se ve con estilos (CSS). Si sale sin estilos, falla la `root` de nginx o el volumen.
- [ ] Subir una imagen en un post. Comprueba permisos de escritura de `www-data` en el volumen.

## D. ⚠ NO COMPROBADO — requisitos del subject

- [ ] **Solo 443**: `curl -I http://crmorale.42.fr` → connection refused.
- [ ] **TLS 1.2/1.3**: `openssl s_client -connect crmorale.42.fr:443 -tls1_2` funciona.
- [ ] **TLS antiguo rechazado**: `openssl s_client -connect crmorale.42.fr:443 -tls1_1` falla. (Si tu openssl no admite `-tls1_1`, basta con que 1.2 y 1.3 funcionen.)
- [ ] **Reinicio tras crash**: `docker kill wordpress` y, a los pocos segundos, `docker ps` → `Up` otra vez. Repetir con `mariadb` y `nginx`.
- [ ] **Persistencia**: crear un post → `make down` → `make` → el post sigue.
- [ ] **Persistencia tras reiniciar la VM**: el post sigue y los contenedores arrancan solos.
- [ ] **Volúmenes**: `docker volume inspect wordpress_data` muestra `device: /home/crmorale/data/wordpress`.
- [ ] **Red**: `docker network inspect inception` muestra los 3 contenedores.
- [ ] **PID 1**: `docker exec wordpress cat /proc/1/comm` → `php-fpm8.2`; en nginx → `nginx`; en mariadb → `mysqld` (o `mariadbd`).
- [ ] **Sin contraseñas en el repo**: `git status` no muestra nada de `secrets/*.txt`, y `grep -ri changeme .` no encuentra nada fuera de `secrets/`.
- [ ] **Sin `latest`**: `grep -rn latest srcs/` → nada.
- [ ] **Sin hacks**: `grep -rnE "tail -f|sleep infinity|while true" srcs/` → nada.

## E. Documentación

- [ ] `README.md` → sección **Use of AI**: revisa que describa lo que hiciste tú de verdad y ajústala si hace falta.
- [ ] Comprobar que los comandos de `USER_DOC.md` y `DEV_DOC.md` coinciden con tu Makefile (punto A).

## F. Repo final

- [ ] `git ls-files` contiene: `Makefile`, `README.md`, `USER_DOC.md`, `DEV_DOC.md`, `.gitignore`, `srcs/.env`, `srcs/docker-compose.yml` y las 3 carpetas de `srcs/requirements/` con su Dockerfile, `.dockerignore`, `conf/` y `tools/`.
- [ ] `git ls-files` **no** contiene nada de `secrets/*.txt` ni este checklist.
- [ ] Clonar el repo en una carpeta limpia, crear los secrets y hacer `make`: tiene que funcionar a la primera.

## G. Preguntas típicas en la defensa (repasa que sabes contestarlas)

- Por qué `exec` y qué es PID 1.
- Diferencia entre imagen y contenedor.
- Cómo se comunican nginx y php-fpm (FastCGI, puerto 9000, red `inception`, DNS por nombre de servicio).
- Por qué php-fpm escucha en TCP y no en un socket unix.
- Las 4 comparativas del README.
- Cómo entra una contraseña desde `secrets/` hasta MariaDB y WordPress.
- Posible modificación en vivo: cambiar el puerto, el título del sitio, añadir un tercer usuario, etc.
