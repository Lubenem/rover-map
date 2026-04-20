# Step 3 Execution Report (Isolated Validation + Bridges + FAST-LIVO2)

Date: 2026-04-16  
Environment: `~/projects/rover-map` + Docker container `rover-map`  
Tmux session: `run-ros`

## Goal
- Follow a strict proof chain:
  1) prove isolated Gazebo/ROS loop,
  2) prove raw sensor topics with non-zero rates,
  3) prove bridge topics,
  4) run FAST-LIVO2 only after raw inputs are proven.

## Windows used
- `iso-core`: isolated ROS+Gazebo master
- `iso-spawn`: model spawn and service checks
- `iso-sensors`: topic/rate validation
- `iso-bridge`: `/laser/scan -> /points_raw`
- `iso-fastro`: `/points_raw -> /livox/lidar`
- `iso-relay`: `/imu -> /livox/imu`
- `iso-livo`: FAST-LIVO2 launch

## 1) Isolated core loop
Command block used in `iso-core`:
```bash
source /opt/ros/noetic/setup.bash
source /workspace/lib/PX4-Autopilot/Tools/setup_gazebo.bash /workspace/lib/PX4-Autopilot /workspace/lib/PX4-Autopilot/build/px4_sitl_default
export ROS_MASTER_URI=http://127.0.0.1:11411
export GAZEBO_MASTER_URI=http://127.0.0.1:11445
export GAZEBO_MODEL_DATABASE_URI=""
roslaunch gazebo_ros empty_world.launch world_name:=/workspace/lib/PX4-Autopilot/Tools/sitl_gazebo/worlds/empty.world gui:=false pause:=false use_sim_time:=false
```

Result:
- PASS: isolated Gazebo ROS API came up cleanly.

## 2) Rover spawn behavior (baseline vs modified)
In `iso-spawn`:
- `rover.sdf.last_generated` spawn:
  - PASS: spawned and `get_model_properties` success.
- `rover.sdf` (current modified runtime file) spawn:
  - FAIL: spawn timeout, then Gazebo process segfaulted (`exit code 139`).

Observed key log signals:
- `RayPlugin requires a Ray Sensor as its parent`
- `Sensors failed to initialize when loading model[rover_base]`

Conclusion:
- Current rover runtime sensor stack is unstable in isolated flow.
- This matches the “sensor publication/integration” blocker.

## 3) Standalone LiDAR proof (no rover)
Model spawned:
- `/workspace/lib/PX4-Autopilot/Tools/sitl_gazebo/models/rplidar/model.sdf` as `rplidar_test`

Topic/rate checks in `iso-sensors`:
- `/laser/scan` exists
- `rostopic hz /laser/scan` ~10 Hz

Important data check:
- FAIL (content): `/laser/scan` ranges are all `inf`
- Therefore `scan_to_cloud` outputs empty cloud (`width: 0`)

Conclusion:
- Transport/rate is alive, but scan content is empty in this run.

## 4) Standalone IMU proof
Added test model:
- `/workspace/tools/test_models/imu_sensor.sdf`

Spawned as `imu_test`:
- PASS: model spawn success.
- PASS: `/imu` topic exists with non-zero rate (~1 Hz observed in this static setup).

## 5) Bridge wiring proof
Running processes:
- `python3 /workspace/tools/scan_to_cloud.py` (`iso-bridge`)
- `python3 /workspace/tools/points_to_livox.py` (`iso-fastro`)
- `rosrun topic_tools relay /imu /livox/imu` (`iso-relay`)

Checks:
- PASS: `/points_raw` exists, ~10 Hz
- PASS: `/livox/lidar` exists, ~10 Hz
- PASS: `/livox/imu` exists, ~1 Hz

Content checks:
- FAIL (content): `/points_raw` has `width: 0`
- FAIL (content): `/livox/lidar` has `point_num: 0`

## 6) FAST-LIVO2 execution
Launched in `iso-livo`:
```bash
source /opt/ros/noetic/setup.bash
source /workspace/catkin_ws/devel/setup.bash
export ROS_MASTER_URI=http://127.0.0.1:11411
export GAZEBO_MASTER_URI=http://127.0.0.1:11445
roslaunch fast_livo mapping_avia.launch rviz:=false
```

Observed:
- FAST-LIVO2 starts.
- Repeated log: `Received an empty point cloud`.
- `/cloud_registered` topic exists but no messages.

Conclusion:
- FAIL end-to-end: mapper has zero valid lidar points, so no map output.

## Added files during this run
- `/workspace/tools/test_models/imu_sensor.sdf`
- `/workspace/tools/test_models/box_obstacle.sdf`
- `/workspace/tools/test_models/wall_obstacle.sdf`

## Current blocker summary
1) Rover runtime sensor integration is unstable (`rover.sdf` path currently crashes Gazebo in isolated loop).
2) Standalone `rplidar` publishes `/laser/scan` at expected rate, but ranges are all `inf` in this environment, so downstream clouds are empty.
3) FAST-LIVO2 pipeline is wired correctly but starved of non-empty lidar points.

## Most direct next technical step
- Replace current standalone laser source with a known non-empty source (either:
  - a validated Gazebo model that returns finite scan ranges in this exact environment, or
  - bag playback for deterministic data),
- then rerun bridge + FAST-LIVO2 checks.
