# Step 1 - Foundation Plan

## Project Name
**`rover-map`**

Why this name:
- simple and clear for rover mapping scope.

## Step 1 Goals
1. Create a reproducible Docker environment dedicated to this project.
2. Automate installation of required dependencies/tools inside the container.
3. Define clear next steps so execution is predictable on any machine.

## 1) Docker-First Foundation (Recreatable)
Use a dedicated folder for infra files (version-controlled):

```text
~/projects/rover-map/
  Makefile
  README.md
  src/
  catkin_ws/
  infra/
    docker/
      Dockerfile
      docker-compose.yml
      .dockerignore
      scripts/
        bootstrap.sh
        entrypoint.sh
```

### Base Image Decision
Use `ubuntu:20.04` because FAST-LIVO2 is ROS1/catkin-oriented and aligns best with ROS Noetic-era dependencies.

### Container Strategy
- One main dev container: `rover-map`
- Mount host workspace as volume for persistence.
- Keep build artifacts in mounted volume, not inside ephemeral container layers.

### Recreate Flow on Any Machine
1. Clone repo/folder containing `infra/docker/*`.
2. Build image with one command.
3. Start container with one command.
4. Bootstrap script installs all system + ROS + project deps.

## 2) Automatic Setup Inside Docker
`bootstrap.sh` should install/configure the following automatically:

### A. System + Build Essentials
- `build-essential`, `cmake`, `git`, `curl`, `wget`, `pkg-config`
- Python tools for ROS workflows (`python3-catkin-tools`)

### B. ROS1 + Core Packages
- `ros-noetic-desktop-full`
- `ros-noetic-pcl-ros`
- `ros-noetic-cv-bridge`
- `ros-noetic-image-transport`
- `ros-noetic-tf`
- `ros-noetic-eigen-conversions`
- `ros-noetic-rviz`

### C. Native Libraries
- `libpcl-dev`, `libeigen3-dev`, `libopencv-dev`, `libboost-all-dev`

### D. FAST-LIVO2 Specific Dependencies
- `Sophus` pinned to commit `a621ff`
- `rpg_vikit`

### E. Workspace Build
- Create `/workspace/catkin_ws/src`
- Clone `FAST-LIVO2` + `rpg_vikit`
- `catkin_make`
- source setup automatically in shell startup

### F. Verification Commands
After bootstrap, these must pass:

```bash
roscore
rospack find fast_livo
roslaunch fast_livo mapping_avia.launch
```

## 3) Next Steps (After Foundation)

### Step 2 - Baseline Validation
- Run FAST-LIVO2 with rosbag first.
- Confirm RViz map on `/cloud_registered` and path on `/path`.

### Step 3 - PX4 + Gazebo Integration
- Start rover SITL simulation.
- Map sim topics into FAST-LIVO2 config (`sim_rover.yaml`).
- Start in LIO mode first (`img_en: 0`), then enable full LIVO if needed.

### Step 4 - Stabilize and Document
- Tune `time_offset.*` and `preprocess.*` as needed.
- Save final launch/config pair used for task submission.
- Capture evidence: screenshot/video + topic rates.

## Definition of Done for Step 1
- Docker files exist and are committed.
- Fresh machine can reproduce env from Docker files.
- Container starts and can run ROS commands.
- Dependency installation is automated (no manual package-by-package setup).

## Practical Command Targets (to implement next)
- `make docker-build`
- `make docker-up`
- `make bootstrap`
- `make test-env`

These targets keep daily workflow simple and repeatable.
