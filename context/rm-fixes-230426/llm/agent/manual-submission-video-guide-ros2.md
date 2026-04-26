# Manual Submission + Video Guide (ROS2)

Date: 2026-04-26

This guide is for manual recording/submission only.
It uses strict real-LiDAR mode, so synthetic fallback is blocked.

## 1) Prep
From host terminal:
```bash
cd /home/liu99/projects/rover-map
make docker-up-ros2
docker compose -f infra/docker/docker-compose.ros2.yml exec -T rover-map-ros2 bash -lc '/workspace/tools/submission_run_ros2.sh stop' || true
tmux kill-session -t run-rm 2>/dev/null || true
```

## 2) Create tmux layout
```bash
tmux new -s run-rm
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
docker compose -f infra/docker/docker-compose.ros2.yml exec rover-map-ros2 bash -lc \
  "/workspace/tools/submission_run_ros2.sh start --foreground --gui --timeout 900 --require-real-lidar --world walls --drive-demo --drive-duration 900"
```
Wait until you see:
- `ROS2 stack started (Phases D/E/G).`
- `LiDAR source: gazebo`
- `Drive demo: 1 (duration=900s)`
- mapper line with `/cloud_registered rate=... width=...`
- Gazebo GUI window with the rover world

### Window `status`
```bash
cd /home/liu99/projects/rover-map
watch -n 2 "make submission-status-ros2"
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
docker compose -f infra/docker/docker-compose.ros2.yml exec -T rover-map-ros2 bash -lc '
  tail -f /workspace/.submission_runtime_ros2/logs/submission_drive_ros2.log /workspace/.submission_runtime_ros2/logs/fast_livo_mapper.log
'
```

## 4) Run verification during recording
### Window `check`
```bash
cd /home/liu99/projects/rover-map
while true; do
  date +"%H:%M:%S"
  docker compose -f infra/docker/docker-compose.ros2.yml exec -T rover-map-ros2 bash -lc \
    "timeout 3 gz topic -e -t /world/walls/dynamic_pose/info | awk '/name: \"rover_differential_0\"/{m=1} m&&/x:/{x=\$2} m&&/y:/{print \"x=\"x\" y=\"\$2; exit}'"
  sleep 3
done
```

Expected:
- `x=... y=...` values keep changing every few seconds (rover is moving).
- In `status`, keep `phase=G`, `require_real_lidar=1`, `lidar_source=gazebo`, non-zero rates.

## 5) What to show in video
1. `core` window startup output (PX4 + Gazebo Harmonic + mapper ready in strict mode).
2. `status` window showing `phase=G`, `require_real_lidar=1`, `lidar_source=gazebo`, and non-zero rates.
3. RViz colored map growth (`/cloud_registered`).
4. `check` window with changing rover coordinates (`x=... y=...`) to prove motion.
5. Keep recording 30-60 more seconds for stability.

## 6) Finish and cleanup
```bash
cd /home/liu99/projects/rover-map
docker compose -f infra/docker/docker-compose.ros2.yml exec -T rover-map-ros2 bash -lc '/workspace/tools/submission_run_ros2.sh stop'
tmux kill-session -t run-rm
```
