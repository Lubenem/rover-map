# Phase G Report - ROS2 Checks and Evidence Automation

Date: 2026-04-23
Phase: G (completed with known carry-over risk)

## Goal
Extend ROS2 submission checks to validate full pipeline including mapper output and color-quality signal.

## What was done
- Upgraded verification script:
  - `tools/submission_check_ros2.sh`
- Added checks for:
  - `/laser/scan rate > 0`
  - `/livox/imu rate > 0`
  - `/points_raw width > 0`
  - `/livox/lidar point_num > 0`
  - `/cloud_registered width > 0 and rate > 0`
  - `reflectivity_variance > 0`
- Extended probe tool for metrics:
  - `tools/ros2_topic_probe.py` now supports width/point_num/reflectivity variance metrics

## Verification
Command run:
```bash
make submission-check-ros2
```
Result summary:
- `/laser/scan rate>0` PASS
- `/livox/imu rate>0` PASS
- `/points_raw width>0` PASS
- `/livox/lidar point_num>0` PASS
- `/cloud_registered width>0 + rate>0` PASS
- `reflectivity_variance>0` PASS
- `PASS_COUNT=6`, `FAIL_COUNT=0`

Evidence directory:
- `artifacts/ros2/submission-check-20260423-184805/`

## Important carry-over risk
- The check pass above is still under `lidar_source=synthetic` runtime fallback.
- This keeps the pipeline verifiable, but real Gazebo lidar publishing is still unresolved.

## Status
CONDITIONAL PASS
