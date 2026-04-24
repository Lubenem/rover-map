# rover-map
Reproducible Docker workspace for rover mapping experiments with FAST-LIVO2.

## Current Scope (2026-04-23)
This repo now contains an active ROS2 pipeline for the fixes request:
- `ROS2 Humble + Gazebo Harmonic + PX4`
- FAST-LIVO2 ROS2 mapper publishing `/cloud_registered`
- color-oriented lidar conversion (non-constant reflectivity)
- automated ROS2 submission checks

Legacy ROS1 tooling is still present for fallback/history, but the current work is centered on ROS2.

## Current Status
Automated ROS2 checks pass with:
- `/laser/scan`, `/livox/imu`, `/points_raw`, `/livox/lidar`, `/cloud_registered`
- reflectivity variance check (`> 0`)

Important known issue:
- real Gazebo rover lidar does not publish in this environment
- runtime currently falls back to synthetic lidar (`lidar_source=synthetic`)
- tracked in: `context/rm-fixes-230426/reports/open-issue-real-gazebo-lidar-fail-report.md`

## Key Make Targets
ROS2 stack:
- `make docker-build-ros2`
- `make docker-up-ros2`
- `make docker-shell-ros2`
- `make test-env-ros2`
- `make submission-start-ros2`
- `make submission-status-ros2`
- `make submission-check-ros2`
- `make submission-stop-ros2`

Legacy ROS1 stack remains available:
- `make docker-build`
- `make docker-up`
- `make docker-shell`
- `make bootstrap`
- `make test-env`

## Quick Start (ROS2)
```bash
cd ~/projects/rover-map
make docker-build-ros2
make docker-up-ros2
make test-env-ros2
make submission-start-ros2
make submission-check-ros2
make submission-stop-ros2
```

## ROS2 Runtime Pipeline
Main flow:
- LiDAR: `/laser/scan -> /points_raw -> /livox/lidar`
- IMU: Gazebo IMU -> `/livox/imu`
- Mapper output: `/cloud_registered`

Main scripts:
- `tools/submission_run_ros2.sh`
- `tools/submission_check_ros2.sh`
- `tools/scan_to_cloud_ros2.py`
- `tools/points_to_livox_ros2.py`
- `tools/imu_relay_ros2.py`
- `tools/laser_scan_relay_ros2.py`
- `tools/synthetic_lidar_ros2.py`
- `tools/ros2_topic_probe.py`

ROS2 mapper/runtime config:
- `config/fast_livo_ros2_rover.yaml`
- `config/fast_livo_ros2_color.rviz`

## Dependencies and `colcon_ws`
The ROS2 mapper path depends on a colcon workspace at `colcon_ws/`.

### Required packages/repos in `colcon_ws/src`
- `FAST-LIVO2-ROS2` (linked from `lib/FAST-LIVO2-ROS2`)
- `livox_ros_driver2`
- `rpg_vikit_ros2_fisheye` (with `vikit_common` and `vikit_ros`)

`colcon_ws` contains build products and embedded third-party repos and is intentionally **not tracked** by Git.

## Git Hygiene
Do not commit generated/runtime folders:
- `colcon_ws/`
- `.submission_runtime/`
- `.submission_runtime_ros2/`
- `artifacts/`
- `log/`
- `tools/__pycache__/`

Do not commit vendored dependency repos under `lib/`.

## Manual Submission / Recording Guide
Use:
- `manual-submission-video-guide-ros2.md`

Phase reports and evidence:
- `context/rm-fixes-230426/reports/`
- `artifacts/ros2/submission-check-<timestamp>/`
