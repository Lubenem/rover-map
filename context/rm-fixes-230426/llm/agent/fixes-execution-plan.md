# Fixes Execution Plan (ELI5)

Date: 2026-04-23
Scope: implement the new fixes from `context/rm-fixes-230426/docs/fixes-request.md`.

## 0) Super Simple Story
We already built a robot demo once.
But it was built with old tools (ROS1 + old Gazebo).
Now the client asked for new tools (ROS2 + Gazebo Harmonic + PX4) and a colorful map.
So we will:
1. Move the whole pipeline to ROS2 + Harmonic.
2. Keep PX4 rover simulation.
3. Make point cloud colors clearly visible (not gray).
4. Re-record clean submission evidence.

## 1) What Was Requested Initially (from original task)
From `context/test-task-130426/docs/task-message.md`:
- Run FAST-LIVO2 on a PX4 + Gazebo rover with LiDAR.
- Drive through a standard map.
- Show generated point cloud in RViz.

## 2) What Was Already Done (from reports + code)
Current implementation is successful, but in ROS1 stack:
- Environment: ROS1 Noetic, catkin, Gazebo Classic.
- Runner/check scripts:
  - `tools/submission_run.sh`
  - `tools/submission_drive.py`
  - `tools/submission_check.sh`
- Final historical evidence exists (`PASS`) in:
  - `context/test-task-130426/submission/submission-evidence-filled-20260420-051648.md`

## 3) New Request and Real Gap
From `context/rm-fixes-230426/docs/fixes-request.md`:
1. Must use `ROS2 + Gazebo Harmonic + PX4`.
2. FAST-LIVO2 output should be color, not gray.

### Current gap
- Repo is hard-wired to ROS1 (`roslaunch`, `rostopic`, catkin, Noetic).
- Docker image is Ubuntu 20.04 + ROS1.
- Bridge nodes set constant reflectivity (`tools/points_to_livox.py` sets `reflectivity = 0`), which can make intensity coloring look gray/flat.

## 4) Research-Based Constraints (important)
- PX4 supports Ubuntu 22.04 and 24.04 in current docs.
- PX4 Gazebo docs state Gazebo Harmonic is the Gazebo line for modern Ubuntu and rover targets exist (`gz_rover_differential`, `gz_rover_ackermann`, `gz_rover_mecanum`).
- Upstream `hku-mars/FAST-LIVO2` is ROS1/catkin (Ubuntu 18.04-20.04 in README).
- A community ROS2 Humble FAST-LIVO2 port exists (`VIS4ROB-lab/FAST-LIVO2-ROS2`, not official upstream).

## 5) Plan of Record (working path)
We use ROS2 Humble + Gazebo Harmonic + PX4 first, because:
- PX4 ROS2 docs give direct guidance for Humble.
- Community FAST-LIVO2 ROS2 port is available for Humble.

If this fails, fallback is ROS2 Jazzy + Harmonic + extra patching.

---

## 6) Execution Phases

## Phase A - Freeze baseline and create migration workspace
Owner: LLM

1. Keep old ROS1 scripts untouched as fallback.
2. Add ROS2-specific files with `_ros2` suffix.
3. Create new docs folder for ROS2 evidence.

Deliverables:
- `tools/submission_run_ros2.sh`
- `tools/submission_check_ros2.sh`
- `tools/submission_drive_ros2.py`
- `context/rm-fixes-230426/report/` (new logs)

Gate to continue:
- old ROS1 flow still runnable (for rollback only).

## Phase B - Install software for ROS2 + Harmonic + PX4
Owner: LLM

1. Add a new Docker image (do not overwrite old one first):
- Ubuntu 22.04 base.
- ROS2 Humble.
- colcon + ros-dev-tools.
- PX4 toolchain deps.
- Gazebo Harmonic packages.
- `ros-humble-ros-gzharmonic` interface packages.

2. Update compose/make targets for ROS2 container.

3. Build sanity checks:
- `ros2 --version`
- `gz sim --versions`
- PX4 build target list works.

Deliverables:
- `infra/docker/Dockerfile.ros2` (or equivalent)
- `infra/docker/docker-compose.ros2.yml`
- `make docker-build-ros2`, `make docker-up-ros2`, `make docker-shell-ros2`

Gate to continue:
- Container starts and all core tools are callable.

## Phase C - PX4 rover in Gazebo Harmonic
Owner: LLM

1. Start PX4 rover in Gazebo Harmonic (example target: `gz_rover_differential`).
2. Choose standard world for demo.
3. Confirm rover exists and moves.

Deliverables:
- command block documented in run script.
- startup log with no fatal errors.

Gate to continue:
- rover runs stably for >= 90 seconds.

## Phase D - ROS2 topic pipeline (LiDAR + IMU)
Owner: LLM

1. Add ROS2/Gazebo bridges (`ros_gz_bridge`) for:
- `/clock`
- LiDAR scan topic
- IMU topic

2. Add/port conversion nodes in ROS2:
- `scan_to_cloud_ros2` (`/laser/scan -> /points_raw`)
- `points_to_livox_ros2` (`/points_raw -> /livox/lidar`)
- IMU path (`/imu -> /livox/imu`) if needed.

3. Keep topic names aligned with mapper config.

Deliverables:
- ROS2 Python/C++ nodes under `tools/` or a ROS2 package.
- launch script wiring all converters.

Gate to continue:
- non-zero rates on `/livox/lidar` and `/livox/imu`.

## Phase E - FAST-LIVO2 on ROS2
Owner: LLM

1. Integrate ROS2 FAST-LIVO2 source (community port) inside `lib/`.
2. Build in colcon workspace.
3. Configure mapper topics to use ROS2 pipeline topics.
4. Launch mapper and verify `/cloud_registered` is publishing.

Deliverables:
- ROS2 workspace build instructions.
- launch command for mapper.

Gate to continue:
- `/cloud_registered` has positive rate and non-zero width.

## Phase F - Fix color output (not gray)
Owner: LLM

### F1 Minimal visible-color fix (fast)
1. Update RViz config for `/cloud_registered`:
- use `Intensity` or `AxisColor` rainbow view.
- enable auto bounds.
- choose clear color map.

### F2 Data-level color fix (robust)
1. In `points_to_livox` ROS2 node, stop using constant reflectivity.
2. Compute pseudo-reflectivity from point range (or scan intensity if available).
3. Normalize to 0..255 and write to `reflectivity` per point.

### F3 Validation
1. Confirm reflectivity values are not all identical.
2. Confirm RViz map shows visible color variation while rover moves.

Deliverables:
- updated RViz config.
- updated conversion node.
- check script with color-variance test.

Gate to continue:
- video shows clearly non-gray cloud.

## Phase G - ROS2 check script and evidence automation
Owner: LLM

Create `tools/submission_check_ros2.sh` to produce PASS/FAIL table for:
- `/laser/scan` rate > 0
- `/livox/imu` (or `/imu`) rate > 0
- `/points_raw` width > 0
- `/livox/lidar` point_num > 0
- `/cloud_registered` width > 0 and rate > 0
- `reflectivity_variance > 0` (new color quality check)

Store outputs under:
- `context/rm-fixes-230426/report/submission-check-<timestamp>/`

Gate to continue:
- PASS on all checks.

---

## 7) Final Submission Algorithm (tmux + recording)
Owner: Mixed (`LLM` prepares scripts, `Manual` records video)

Create tmux session `rm-fixes` with these windows:
1. `core` (PX4 + Gazebo Harmonic)
2. `bridge` (ros_gz_bridge)
3. `convert` (scan->cloud + cloud->livox + imu relay)
4. `mapper` (FAST-LIVO2 ROS2)
5. `rviz` (RViz2)
6. `drive-check` (drive command + checks)

## Start order (important)
1. Window `core`:
- start PX4 SITL rover in Gazebo Harmonic.

2. Window `bridge`:
- start ROS2 <-> Gazebo topic bridges.

3. Window `convert`:
- start conversion nodes.

4. Window `mapper`:
- start FAST-LIVO2 ROS2 mapping node.

5. Window `rviz`:
- open RViz2 with final fixed config.

6. Window `drive-check`:
- run deterministic drive script for 90s.
- run submission check script.

## What to record in video (manual)
Minute 0:
- Show `core` startup output (PX4 + Gazebo Harmonic).
- Show world and rover spawned.

Minute 1:
- Show `bridge` + `convert` windows with running processes.
- Briefly show topic rates in `drive-check`.

Minute 2:
- Show RViz2 map growing with visible color variation.
- Keep rover movement visible in Gazebo.

Minute 3:
- Run `submission_check_ros2.sh`.
- Show final PASS table.
- Keep recording another 30-60 seconds of stable mapping.

## Must-capture screenshots
1. Gazebo window with rover moving.
2. RViz2 window with clearly colored point cloud map.
3. Terminal with PASS table and timestamped evidence path.

---

## 8) Definition of Done
Done means ALL are true:
- stack is ROS2 + Gazebo Harmonic + PX4.
- no synthetic fake source in final run.
- FAST-LIVO2 publishes `/cloud_registered` in final flow.
- cloud is visibly colored (not gray) in RViz2.
- check script passes all metrics including reflectivity variance.
- video + screenshots + evidence file are prepared.

## 9) Risk and fallback rules
1. If ROS2 FAST-LIVO2 port fails to build:
- patch locally in ROS2 workspace first.
- keep change log of every patch.

2. If Humble + Harmonic package conflict appears:
- use documented `ros-humble-ros-gzharmonic` path and remove conflicting `ros-humble-ros-gz`.
- if still blocked, move to Jazzy + Harmonic track.

3. If color still looks gray:
- verify reflectivity distribution in `/livox/lidar`.
- enforce RViz auto intensity bounds and rainbow transformer.
- as backup, use `AxisColor (Z)` for display clarity.

---

## 10) References Used For This Plan
Local project evidence:
- `context/test-task-130426/docs/task-message.md`
- `context/test-task-130426/plan/report/*.md`
- `tools/submission_run.sh`
- `tools/submission_check.sh`
- `tools/points_to_livox.py`
- `lib/fast-livo2/src/LIVMapper.cpp`
- `lib/fast-livo2/rviz_cfg/fast_livo2.rviz`

External docs checked (2026-04-23):
- PX4 Gazebo Simulation docs: https://docs.px4.io/main/en/sim_gazebo_gz/
- PX4 ROS2 User Guide: https://docs.px4.io/main/en/ros2/user_guide
- PX4 Ubuntu setup: https://docs.px4.io/main/en/dev_setup/dev_env_linux_ubuntu
- Gazebo Harmonic + ROS install matrix: https://gazebosim.org/docs/harmonic/ros_installation/
- FAST-LIVO2 upstream: https://github.com/hku-mars/FAST-LIVO2
- FAST-LIVO2 ROS2 community port: https://github.com/VIS4ROB-lab/FAST-LIVO2-ROS2
