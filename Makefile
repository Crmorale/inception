include srcs/.env

DATA_DIR := /home/$(LOGIN)/data
COMPOSE  := docker compose -f srcs/docker-compose.yml --env-file srcs/.env
SECRETS  := secrets/db_password.txt secrets/db_root_password.txt secrets/credentials.txt

all: up

check_secrets:
	@for f in $(SECRETS); do \
		[ -s $$f ] || { echo "Missing or empty secret: $$f"; exit 1; }; \
	done
	@chmod 700 secrets
	@chmod 600 $(SECRETS)

dirs:
	@mkdir -p $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress

up: check_secrets dirs
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f

clean: down
	$(COMPOSE) down -v --rmi all

fclean: clean
	sudo rm -rf $(DATA_DIR)
	docker system prune -af

re: fclean all

.PHONY: all check_secrets dirs up down stop start ps logs clean fclean re
