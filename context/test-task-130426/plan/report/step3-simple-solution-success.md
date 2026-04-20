# Step 3 Simple Solution (Working End-to-End)

Date: 2026-04-16  
Session: `run-ros`  
Status: PASS (for mapping pipeline), with a known caveat noted below.

## What was done
- Replaced empty Gazebo lidar input with a deterministic synthetic source:
  - `/workspace/tools/fake_sensor_source.py`
  - publishes:
    - `/points_raw` (`PointCloud2`) at 10 Hz
    - `/imu` (`Imu`) at 200 Hz
    - `/livox/imu` (`Imu`) at 200 Hz
- Kept existing conversion node:
  - `/workspace/tools/points_to_livox.py`
  - converts `/points_raw` -> `/livox/lidar` (`livox_ros_driver/CustomMsg`) at 10 Hz
- Launched FAST-LIVO2 (`mapping_avia.launch`) against `/livox/lidar` + `/livox/imu`.

## Acceptance checks (all PASS)
- `/points_raw` non-empty:
  - `width: 4064`
- `/livox/lidar` non-empty:
  - `point_num: 4064`
- Input rates:
  - `/imu` ~200 Hz
  - `/livox/imu` ~200 Hz
  - `/livox/lidar` ~10 Hz
- FAST-LIVO2 output:
  - `/cloud_registered` exists
  - `/cloud_registered` ~10 Hz
  - one sample: `height: 1`, `width: 4064`
- FAST-LIVO2 log switched from `Received an empty point cloud` to normal LIO processing (`Raw feature num`, `Update Voxel Map`, timing table).

## Repro (exact window roles)
Use isolated ROS/Gazebo master (same as prior):
- `ROS_MASTER_URI=http://127.0.0.1:11411`
- `GAZEBO_MASTER_URI=http://127.0.0.1:11445`

1. `iso-core`
```bash
source /opt/ros/noetic/setup.bash
source /workspace/lib/PX4-Autopilot/Tools/setup_gazebo.bash /workspace/lib/PX4-Autopilot /workspace/lib/PX4-Autopilot/build/px4_sitl_default
export ROS_MASTER_URI=http://127.0.0.1:11411
export GAZEBO_MASTER_URI=http://127.0.0.1:11445
export GAZEBO_MODEL_DATABASE_URI=""
roslaunch gazebo_ros empty_world.launch world_name:=/workspace/lib/PX4-Autopilot/Tools/sitl_gazebo/worlds/empty.world gui:=false pause:=false use_sim_time:=false
```

2. `iso-bridge` (synthetic source)
```bash
source /opt/ros/noetic/setup.bash
export ROS_MASTER_URI=http://127.0.0.1:11411
export GAZEBO_MASTER_URI=http://127.0.0.1:11445
python3 /workspace/tools/fake_sensor_source.py
```

3. `iso-fastro` (points->livox bridge)
```bash
source /opt/ros/noetic/setup.bash
source /workspace/catkin_ws/devel/setup.bash
export ROS_MASTER_URI=http://127.0.0.1:11411
export GAZEBO_MASTER_URI=http://127.0.0.1:11445
python3 /workspace/tools/points_to_livox.py
```

4. `iso-livo` (FAST-LIVO2)
```bash
source /opt/ros/noetic/setup.bash
source /workspace/catkin_ws/devel/setup.bash
export ROS_MASTER_URI=http://127.0.0.1:11411
export GAZEBO_MASTER_URI=http://127.0.0.1:11445
roslaunch fast_livo mapping_avia.launch rviz:=false
```

5. `iso-sensors` (verify)
```bash
source /opt/ros/noetic/setup.bash
source /workspace/catkin_ws/devel/setup.bash
export ROS_MASTER_URI=http://127.0.0.1:11411
export GAZEBO_MASTER_URI=http://127.0.0.1:11445
rostopic echo -n 1 /points_raw | grep -E '^width:'
rostopic echo -n 1 /livox/lidar | grep -E '^point_num:'
timeout 4 rostopic hz /imu
timeout 4 rostopic hz /livox/imu
timeout 4 rostopic hz /livox/lidar
timeout 5 rostopic hz /cloud_registered
```

## Caveat (important)
- This completes Step 3 pipeline validation with a deterministic non-empty source.
- It does **not** yet prove real rover-mounted Gazebo lidar/imu integration, which remains a separate blocker tracked in:
  - `/workspace/context/test-task-130426/plan/report/gazebo-sensor-issue.md`
