# Advise1 Follow-up Report

Date: 2026-04-25
Owner: Codex agent
Scope: Apply `advise1.md` and re-verify strict real-Gazebo LiDAR pipeline.

## What Was Changed

1. Enforced strict real-LiDAR mode (already in place from previous phase):
- `tools/submission_run_ros2.sh` supports `--require-real-lidar` and hard-fails instead of synthetic fallback.
- `tools/submission_check_ros2.sh` has an explicit gate `lidar_source==gazebo`.
- `Makefile` includes `submission-start-ros2-real` target.

2. Fixed source-of-truth issue for rover model patching:
- Updated `tools/submission_run_ros2.sh` so `prepare_rover_lidar_overlay()` now patches the PX4 rover model file directly (single source of truth), instead of creating a runtime override that PX4 was not actually spawning.

3. Patched rover sensor to Harmonic-compatible pattern:
- Updated `lib/PX4-Autopilot-ros2/Tools/simulation/gz/models/rover_differential/model.sdf`
- Replaced `submission_lidar_sensor` from `type="lidar"` + `<lidar>` block to `type="gpu_lidar"` + `<ray>` block.
- Removed custom `<topic>lidar</topic>` override, letting Gazebo publish on canonical world/model sensor topic.

4. Updated manual recording guide for final-safe run:
- `context/rm-fixes-230426/llm/agent/manual-submission-video-guide-ros2.md`
- Now uses strict start command and requires `PASS_COUNT=7`, `lidar_source=gazebo`.

## Why This Fix Was Needed

During strict run diagnostics, PX4 logs showed model loading from:
- `/workspace/lib/PX4-Autopilot-ros2/Tools/simulation/gz/models/rover_differential/model.sdf`

This proved runtime model override was not the active source. The direct PX4 model patch removed ambiguity and made LiDAR sensor behavior deterministic.

## Verification Executed

Commands executed:
```bash
make submission-stop-ros2 || true
make submission-start-ros2-real
make submission-status-ros2
make submission-check-ros2
make submission-stop-ros2
```

Observed strict start result:
- `LiDAR source: gazebo`
- `LiDAR topic: /world/rover/model/rover_differential_0/link/base_link/sensor/submission_lidar_sensor/scan`
- non-zero rates on `/livox/lidar`, `/livox/imu`, `/cloud_registered`

Observed check result:
- `lidar_source==gazebo PASS`
- `PASS_COUNT=7`
- `FAIL_COUNT=0`

Evidence directory:
- `artifacts/ros2/submission-check-20260425-142039/`

## Outcome

Status: PASS

The previous blocker (synthetic LiDAR fallback) is resolved for strict mode final runs. The pipeline now meets the acceptance gate with real Gazebo LiDAR source and 7/7 check passes.
