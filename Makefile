COMPOSE_FILE=infra/docker/docker-compose.yml
SERVICE=rover-map

.PHONY: docker-build docker-up docker-down docker-shell bootstrap test-env

docker-build:
	docker compose -f $(COMPOSE_FILE) build

docker-up:
	docker compose -f $(COMPOSE_FILE) up -d

docker-down:
	docker compose -f $(COMPOSE_FILE) down

docker-shell:
	docker compose -f $(COMPOSE_FILE) exec $(SERVICE) bash

bootstrap:
	docker compose -f $(COMPOSE_FILE) exec $(SERVICE) bash -lc "/workspace/infra/docker/scripts/bootstrap.sh"

test-env:
	docker compose -f $(COMPOSE_FILE) exec $(SERVICE) bash -lc "/workspace/infra/docker/scripts/test-env.sh"
