# Manual Submission + Video Guide (ROS2)

Date: 2026-04-23

This guide is for manual recording/submission only.
It uses the implemented ROS2 scripts and keeps commands deterministic.

## 1) Prep
From host terminal:
```bash
cd /home/liu99/projects/rover-map
make docker-up-ros2
make submission-stop-ros2 || true
```

## 2) Create tmux layout
```bash
tmux new -s rm-fixes
```

Create windows:
1. `core`
```bash
tmux rename-window core
```
2. `status`
```bash
tmux new-window -n status
```
3. `rviz`
```bash
tmux new-window -n rviz
```
4. `check`
```bash
tmux new-window -n check
```
5. `logs`
```bash
tmux new-window -n logs
```

## 3) Start order
### Window `core`
```bash
cd /home/liu99/projects/rover-map
make submission-start-ros2
```
Wait until you see:
- `ROS2 stack started (Phases D/E/G).`
- mapper line with `/cloud_registered rate=... width=...`

### Window `status`
```bash
cd /home/liu99/projects/rover-map
watch -n 2 'make submission-status-ros2'
```

### Window `rviz`
```bash
cd /home/liu99/projects/rover-map
docker compose -f infra/docker/docker-compose.ros2.yml exec rover-map-ros2 bash -lc '
  source /opt/ros/humble/setup.bash
  source /workspace/colcon_ws/install/setup.bash
  rviz2 -d /workspace/config/fast_livo_ros2_color.rviz
'
```

### Window `logs`
```bash
cd /home/liu99/projects/rover-map
docker compose -f infra/docker/docker-compose.ros2.yml exec rover-map-ros2 bash -lc '
  tail -f /workspace/.submission_runtime_ros2/logs/fast_livo_mapper.log
'
```

## 4) Run verification during recording
### Window `check`
```bash
cd /home/liu99/projects/rover-map
make submission-check-ros2
```

Expected table should end with:
- `PASS_COUNT=6`
- `FAIL_COUNT=0`

Evidence path format:
- `artifacts/ros2/submission-check-<timestamp>/`

## 5) What to show in video
1. `core` window startup output (PX4 + Gazebo Harmonic + mapper ready).
2. `status` window showing `phase=G` and non-zero rates.
3. RViz colored map growth (`/cloud_registered`).
4. `check` window PASS table and evidence directory.
5. Keep recording 30-60 more seconds for stability.

## 6) Finish and cleanup
```bash
cd /home/liu99/projects/rover-map
make submission-stop-ros2
```

## 7) Important note for reviewer
Current runtime may show:
- `lidar_source=synthetic`
This is tracked in:
- `context/rm-fixes-230426/reports/open-issue-real-gazebo-lidar-fail-report.md`
