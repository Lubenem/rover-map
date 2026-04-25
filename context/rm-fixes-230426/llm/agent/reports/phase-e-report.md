# Phase E Report - FAST-LIVO2 on ROS2

Date: 2026-04-23
Phase: E (completed with critical open risk)

## Goal
Integrate ROS2 FAST-LIVO2, build it in colcon, and verify `/cloud_registered` publishes.

## What was done
- Integrated ROS2 FAST-LIVO2 source:
  - `lib/FAST-LIVO2-ROS2`
  - linked in workspace via `colcon_ws/src/FAST-LIVO2-ROS2`
- Installed required ROS2-side dependencies and built mapper package:
  - `fast_livo` now builds and installs under `colcon_ws/install/fast_livo`
- Fixed FAST-LIVO2 ROS2 CMake linkage to vikit libs for this workspace.
- Wired mapper startup in runtime orchestrator:
  - `tools/submission_run_ros2.sh` now starts `fastlivo_mapping`
  - mapper params file: `config/fast_livo_ros2_rover.yaml`

## Verification
Command run:
```bash
make submission-start-ros2
```
Observed runtime output:
- `ROS2 stack started (Phases D/E/G).`
- `Mapper: /cloud_registered rate=15.034220 width=720`

Additional probe:
```bash
python3 /workspace/tools/ros2_topic_probe.py \
  --topic /cloud_registered \
  --msg-type sensor_msgs/msg/PointCloud2 \
  --timeout 10 --min-msgs 3 --metric pointcloud_width
```
Result:
- `count=3 rate=14.885112 width_max=720`

## Critical open issue (must be reviewed)
- Runtime still auto-falls back to synthetic lidar:
  - `lidar_source=synthetic`
  - `lidar_gz_topic=/phase_d/fallback_scan`
- Mapper works and publishes `/cloud_registered`, but this is not yet a fully real Gazebo lidar chain.

## Status
CONDITIONAL PASS
