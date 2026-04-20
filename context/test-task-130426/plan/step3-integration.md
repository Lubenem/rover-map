# Step 3 – LIO Integration & Demo Run

Goal
- Feed PX4/Gazebo rover sensor topics into FAST-LIVO2 and demonstrate a live run (mapping) with RViz/Cloud outputs.

Prereqs (from Step 2)
- tmux session `run-ros` with windows: `roscore`, `sim`, `sensors` working.
- ROS topics available: `/imu` (~83 Hz), `/laser/scan` (~10 Hz), `/clock`.

Planned layout (add windows)
- `bridge`   : topic remap/bridge nodes (scan->cloud, namespacing).
- `fast`     : run FAST-LIVO2 launch.
- `viz`      : RViz (optional GUI).

Work items
1) Topic prep
   - Decide target topics FAST-LIVO2 expects (likely `/livox/lidar` or PointCloud2, `/livox/imu` or `/imu`).
   - Add a minimal node/launch to convert `/laser/scan` -> `sensor_msgs/PointCloud2` and remap names as needed.
   - Ensure frame_ids (`imu_link`, `rplidar_link`) match FAST-LIVO2 config.

2) Config FAST-LIVO2
   - Copy/adjust config file in `lib/fast-livo2/config` for our topic names and frame_ids.
   - Update launch (e.g., `mapping_avia.launch`) remaps to sim topics.

3) Run stack
   - `roscore` (already running).
   - `sim` (PX4 + Gazebo) already running.
   - `bridge` window: start scan->cloud bridge (e.g., `rosrun pointcloud_to_laserscan cloudify ...` or custom node) and any remap/static_tf publishers.
   - `fast` window: `roslaunch fast_livo mapping_avia.launch rviz:=false` (with remaps).
   - `viz` window: `rviz` (preload a config pointing to odom, map, point cloud).

4) Validation
   - `rostopic hz` on FAST-LIVO2 input topics shows traffic.
   - FAST-LIVO2 logs show keyframes/odometry outputs; topics like `/cloud_registered`, `/odom` exist.
   - RViz displays point cloud and trajectory without drops.

5) Stretch (optional)
   - Record a bag of the sim run for regression: `rosbag record -O /workspace/data/sim_run.bag /imu /laser/scan /cloud_registered /odom`.
   - Benchmark CPU load; adjust rates if needed.

Sequencing (tiny steps)
- T1: Add/choose bridge method; verify `/points_raw` (or chosen) publishes.
- T2: Edit FAST-LIVO2 config/launch remaps; run node; watch logs for missing topics.
- T3: Start RViz and verify visuals.
- T4: Optional rosbag record.

Artifacts to create in this step
- Small bridge launch or node under `catkin_ws/src` (untracked) or minimal script in `lib/patches` if needed.
- Config/launch overrides for FAST-LIVO2 (keep copies in repo under `context/.../plan/` or patch files if touching upstream).

Exit criteria
- With sim running, FAST-LIVO2 runs without missing-topic errors, publishes odom/cloud, and RViz shows live map.
