# Submission Operator Guide

Goal: run a repeatable PX4 + Gazebo + FAST-LIVO2 demo, move rover in a standard map, and record Gazebo + RViz evidence.

## Prerequisites
- Docker container is available (`rover-map`).
- You record screen manually (video + screenshots).

## Terminal Setup
Use 2 terminal tabs.

### Terminal A (stack control)
```bash
cd ~/projects/rover-map
make docker-up
make docker-shell
source /opt/ros/noetic/setup.bash
source /workspace/catkin_ws/devel/setup.bash
```

Start final stack (primary world `warehouse`, fallback `yosemite`):
```bash
/workspace/tools/submission_run.sh
```

Expected:
- prints `Submission stack started.`
- prints selected world path
- prints runtime env path `/workspace/.submission_runtime/env.sh`
- first startup can take ~1-2 minutes while world assets load

### Terminal B (motion + checks)
```bash
cd ~/projects/rover-map
make docker-shell
source /workspace/.submission_runtime/env.sh
source /opt/ros/noetic/setup.bash
source /workspace/catkin_ws/devel/setup.bash
```

Start deterministic motion:
```bash
python3 /workspace/tools/submission_drive.py --duration 90
```

Run readiness checks (can be repeated):
```bash
/workspace/tools/submission_check.sh
```

Expected:
- all rows show `PASS`
- evidence folder created under:
  - `/workspace/context/test-task-130426/plan/communication/agent/submission-check-<timestamp>`

## Timed Capture Script (Record This)
### Minute 0
1. Start recording.
2. Show Terminal A with `/workspace/tools/submission_run.sh` output (world, model, runtime env).
3. Show Gazebo window with rover in standard world.

### Minute 1
1. Start `submission_drive.py` in Terminal B.
2. Keep Gazebo visible for rover movement.

### Minute 2
1. Show RViz with `fast_livo2.rviz`.
2. Confirm map is growing from `/cloud_registered`.

### Minute 3
1. Run `/workspace/tools/submission_check.sh`.
2. Show PASS table in Terminal B.
3. Stop recording after 60-120s of continuous map growth.

## Required Screenshots
1. Gazebo: rover moving in standard world.
2. RViz: accumulated point cloud map (`/cloud_registered`) clearly visible.

## Stop Stack
In Terminal A:
```bash
/workspace/tools/submission_run.sh stop
```

## Notes
- Final demo model is fixed: `rover_no_velodyne_rplidar_imu.sdf`.
- Runtime FAST-LIVO2 blind filter override is applied by runner: `/preprocess/blind=0.1`.
