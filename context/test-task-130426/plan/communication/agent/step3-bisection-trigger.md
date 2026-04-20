# Step 3 Crash Bisection (Sage Advice 3)

Isolated loop used for each run:
- ROS master: `http://127.0.0.1:11411`
- Gazebo master: `http://127.0.0.1:11445`
- World: `empty.world`
- Spawn target: `/tmp/test_rover_*.sdf`

## Tiny result table

- baseline (`/tmp/test_rover_baseline.sdf` from `rover.sdf.last_generated`): **FAIL**
  - Evidence: `process[gazebo-2] has died ... exit code 139` and `/gazebo/get_world_properties` unavailable after ~20s.

- imu-only (`/tmp/test_rover_imu_only.sdf`): **FAIL**
  - Evidence: `/imu` topic appears but no messages, then `exit code 139`.
  - Core log immediately before crash includes ROS IMU plugin setup lines (`topicName /imu`, `frameName imu_link`, `missing <updateRateHZ>`).

- lidar-only (`/tmp/test_rover_lidar_only.sdf`): **FAIL**
  - Evidence: no `/laser/scan`, then `exit code 139`.

- combined (`/tmp/test_rover_combined.sdf`): **FAIL**
  - Evidence: `/imu` appears but no traffic, then `exit code 139`.

- first crash trigger: **the rover Velodyne sensor block** (baseline block), specifically:
  - `<sensor name="velodyne" type="gpu_ray"> ...`
  - plugin `libgazebo_ros_velodyne_laser.so`
  - Gazebo log signal: `RayPlugin requires a Ray Sensor as its parent`

## Single proving control

- no-velodyne control (`/tmp/test_rover_no_velodyne.sdf`, baseline with only velodyne link/sensor/joint removed): **PASS**
  - `/clock` publishes at ~250 Hz.
  - `/gazebo/get_world_properties` stays available after 25s.
  - `gzserver` stays alive (no segfault in core log).

## One-sentence conclusion

Gazebo crashes when the rover’s Velodyne block (`velodyne` `gpu_ray` + `libgazebo_ros_velodyne_laser.so`) is present.
