Run these from your host terminal in ~/projects/rover-map:

  1. `cd ~/projects/rover-map`
     Changes current directory to your project root, so make can find the project Makefile.
  2. `make docker-build`
     Builds the Docker image (rover-map:dev) from projects/rover-map/infra/docker/Dockerfile using projects/rover-map/infra/docker/docker-compose.yml.
  3. `make docker-up`
     Starts the container (rover-map) in detached mode (-d). If it does not exist yet, it gets created.
  4. `make bootstrap`
     Runs projects/rover-map/infra/docker/scripts/bootstrap.sh inside the running container.
     It automatically:

  - clones FAST-LIVO2, rpg_vikit, Sophus
  - pins Sophus to commit a621ff, builds and installs it
  - links repos into /workspace/catkin_ws/src
  - runs catkin_make
  - adds ROS/catkin source lines to ~/.bashrc in the container

  5. `make test-env`
     Runs projects/rover-map/infra/docker/scripts/test-env.sh inside the container.
     It verifies:

  - ROS distro is available
  - fast_livo package is discoverable (rospack find fast_livo)
  - launch file is resolvable (roslaunch --files fast_livo mapping_avia.launch)

  Useful extra commands:

  1. `make docker-shell`
     Open an interactive shell inside the container.
  2. `make docker-down`
     Stop and remove the running project container.
