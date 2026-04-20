# Gazebo Rover Sensor Publish Issue

## What we expected
- Spawn the PX4 rover model in Gazebo and get ROS topics `/imu` and `/laser/scan` via the sensors defined in `Tools/sitl_gazebo/models/rover/rover.sdf`.

## Current symptom
- `rostopic list` shows only `/clock` and `/gazebo/*`; no `/imu` or `/laser/scan`.
- `rostopic hz /imu` and `/laser/scan` report “topic not published”.
- `/gazebo/model_states` stays empty (timeouts), so the rover model likely isn’t spawned.

## What we changed
- Added ROS IMU and Hokuyo 2D lidar into `rover.sdf`:
  - IMU plugin: `libgazebo_ros_imu_sensor.so` publishing `/imu`.
  - Lidar: Hokuyo `<include>` intended to publish `/laser/scan`.
- Ensured `GAZEBO_PLUGIN_PATH` and `GAZEBO_MODEL_PATH` include default Gazebo paths and PX4 `sitl_gazebo` paths.
- Catkin workspace rebuilt earlier (fast-livo, livox drivers) — builds succeed.

## Attempts logged
- `gzserver` launched via `px4_sitl` and via `roslaunch gazebo_ros empty_world.launch`; server runs.
- Multiple `gz model --spawn-file ...rover.sdf --model-name rover` attempts (with/without `GAZEBO_MASTER_URI`); no visible errors, but model never appears in `/gazebo/model_states`.
- `/tmp/gzserver.log` now shows IMU plugin loads; previous laser plugin errors resolved by switching to Hokuyo include. No successful spawn messages recorded.

## Likely root causes to investigate
1) Model not spawning: `gazebo_ros spawn_model` may be failing silently (wrong master URI/world name or timing), so sensors never start.
2) Hokuyo include won’t publish until the model is actually in the world; absence of `/gazebo/model_states` confirms spawn failure.
3) Spawn timing/order: need to wait for `gzserver` to be fully ready before calling `spawn_model`.

## Suggested next checks
- In container with ROS env sourced:  
  `export GAZEBO_MASTER_URI=http://127.0.0.1:11345`  
  `rosrun gazebo_ros spawn_model -sdf -file /workspace/lib/PX4-Autopilot/Tools/sitl_gazebo/models/rover/rover.sdf -model rover -verbose`  
  Watch `/tmp/gzserver.log` for spawn result.
- After a spawn attempt, check `/gazebo/model_states` for `rover`. If absent, try spawning a small known model (e.g., `model://hokuyo`) to confirm the spawn path works.
- If spawn succeeds but `/laser/scan` is missing, look for “RayPlugin requires a Ray Sensor” in the log — indicates a plugin/sensor mismatch.

## Goal reminder
- We need `/imu` and `/laser/scan` in ROS to drive the Livox bridge and FAST-LIVO2. The priority fix is getting the rover model to spawn and its IMU/laser plugins to load successfully.
