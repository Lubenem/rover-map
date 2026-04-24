COMPOSE_FILE=infra/docker/docker-compose.yml
SERVICE=rover-map
COMPOSE_FILE_ROS2=infra/docker/docker-compose.ros2.yml
SERVICE_ROS2=rover-map-ros2

.PHONY: docker-build docker-up docker-down docker-shell bootstrap test-env
.PHONY: docker-build-ros2 docker-up-ros2 docker-down-ros2 docker-shell-ros2 test-env-ros2
.PHONY: submission-start-ros2 submission-status-ros2 submission-stop-ros2 submission-check-ros2
.PHONY: px4-prepare-ros2

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

docker-build-ros2:
	docker compose -f $(COMPOSE_FILE_ROS2) build

docker-up-ros2:
	docker compose -f $(COMPOSE_FILE_ROS2) up -d

docker-down-ros2:
	docker compose -f $(COMPOSE_FILE_ROS2) down

docker-shell-ros2:
	docker compose -f $(COMPOSE_FILE_ROS2) exec $(SERVICE_ROS2) bash

test-env-ros2:
	docker compose -f $(COMPOSE_FILE_ROS2) exec $(SERVICE_ROS2) bash -lc "/workspace/infra/docker/scripts/test-env-ros2.sh"

px4-prepare-ros2:
	./tools/setup_px4_ros2.sh

submission-start-ros2:
	docker compose -f $(COMPOSE_FILE_ROS2) exec $(SERVICE_ROS2) bash -lc "/workspace/tools/submission_run_ros2.sh start --headless --timeout 900"

submission-status-ros2:
	docker compose -f $(COMPOSE_FILE_ROS2) exec $(SERVICE_ROS2) bash -lc "/workspace/tools/submission_run_ros2.sh status"

submission-stop-ros2:
	docker compose -f $(COMPOSE_FILE_ROS2) exec $(SERVICE_ROS2) bash -lc "/workspace/tools/submission_run_ros2.sh stop"

submission-check-ros2:
	docker compose -f $(COMPOSE_FILE_ROS2) exec $(SERVICE_ROS2) bash -lc "/workspace/tools/submission_check_ros2.sh"
