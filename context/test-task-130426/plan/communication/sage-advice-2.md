# Sage Advice 2

This is the practical reading of the situation.

Step 3 is partially solved.
- The FAST-LIVO2 side is proven with deterministic synthetic inputs.
- The bridge path is proven: `/points_raw` -> `/livox/lidar` -> FAST-LIVO2 -> `/cloud_registered`.
- The unsolved part is narrower: real rover-mounted Gazebo sensors.

That means the other agent should stop debugging FAST-LIVO2 itself.
The mapper is no longer the main suspect.

## What is actually true now

### Proven
- `tools/fake_sensor_source.py` gives a deterministic non-empty source.
- `tools/points_to_livox.py` works for `/points_raw` -> `/livox/lidar`.
- FAST-LIVO2 runs and publishes `/cloud_registered` with that synthetic source.

### Not proven
- Real rover LiDAR data feeding the pipeline reliably.
- Real rover ROS IMU publication feeding the pipeline reliably.
- Real PX4 + Gazebo rover sensors replacing the synthetic source end to end.

So the correct framing is:
- mapping pipeline: working,
- rover sensor integration: still broken or incomplete.

## Missing links in our process

1. We mixed source files and runtime files.
- `lib/PX4-Autopilot/Tools/sitl_gazebo/models/rover/rover.sdf.jinja` is the tracked template.
- `lib/PX4-Autopilot/Tools/sitl_gazebo/models/rover/rover.sdf` is the runtime file actually spawned.
- `lib/PX4-Autopilot/Tools/sitl_gazebo/models/rover/rover.sdf.last_generated` is a useful clean reference snapshot.
- If you patch only `rover.sdf`, you can make progress that is real at runtime but poorly preserved.

2. We treated all IMU plugins as equivalent.
- They are not.
- PX4's built-in `libgazebo_imu_plugin.so` is there for PX4/Gazebo internals, not automatically as a ROS IMU publisher.
- The ROS Gazebo IMU plugins are separate plugins with their own configuration model. Official Gazebo ROS docs expose both a `GazeboRosIMU` model plugin and a `GazeboRosImuSensor` sensor plugin. citeturn2view1turn4view0

3. We started debugging downstream before upstream was proven.
- Since FAST-LIVO2 already works with a deterministic source, the next effort should be only on real sensor publication.
- Do not spend more cycles on `mapping_avia.launch` unless a real rover topic is already flowing.

4. We blurred “topic exists” and “topic publishes usable data”.
- A topic name in `rostopic list` is not enough.
- The acceptance test is traffic plus sane message content and stable rate.

## Best-practice conclusions

From the official FAST-LIVO2 repo, the normal integration point is configurable ROS topics (`lid_topic`, `imu_topic`), and the example path is `mapping_avia.launch`; FAST-LIVO2 is not tied to one single upstream simulator setup as long as the expected topics and message types are correct. citeturn2view0turn1search0

From the official PX4 Gazebo classic repo, some models are generated from Jinja templates, so sensor edits should be made in the template or in a clearly separate test model, not as ad-hoc drift in the generated runtime SDF. The same repo also recommends setting Gazebo plugin/model paths explicitly and disabling online model lookup when stability matters. citeturn3search0turn1search1

From the official Gazebo ROS plugin docs, ROS IMU publication should be treated as an explicit plugin integration task with clear link/topic/frame/update configuration, not assumed to appear automatically from PX4's native Gazebo plugins. citeturn2view1turn4view0

## The simple and best path forward

### Principle
Work from upstream to downstream, one proof at a time.

### Phase 1 - freeze the fallback that already works
The current synthetic Step 3 path is your safety net.
Do not destabilize it.

Preserve these as known-good artifacts:
- `tools/fake_sensor_source.py`
- `tools/points_to_livox.py`
- the current FAST-LIVO2 launch/config used for the successful synthetic run
- any command transcript or report proving `/cloud_registered` was non-empty

### Phase 2 - isolate real sensor debugging from FAST-LIVO2
Do not run the whole stack first.
Use a clean two-shell loop.

Shell A:
```bash
source /opt/ros/noetic/setup.bash
source /workspace/lib/PX4-Autopilot/Tools/setup_gazebo.bash \
  /workspace/lib/PX4-Autopilot \
  /workspace/lib/PX4-Autopilot/build/px4_sitl_default
export ROS_MASTER_URI=http://127.0.0.1:11411
export GAZEBO_MASTER_URI=http://127.0.0.1:11445
export GAZEBO_MODEL_DATABASE_URI=""
roslaunch gazebo_ros empty_world.launch \
  world_name:=/workspace/lib/PX4-Autopilot/Tools/sitl_gazebo/worlds/empty.world \
  gui:=false pause:=false use_sim_time:=false
```

Shell B:
```bash
source /opt/ros/noetic/setup.bash
export ROS_MASTER_URI=http://127.0.0.1:11411
export GAZEBO_MASTER_URI=http://127.0.0.1:11445
rosrun gazebo_ros spawn_model -sdf \
  -file /workspace/lib/PX4-Autopilot/Tools/sitl_gazebo/models/rover/rover.sdf \
  -model rover_test
rosservice call /gazebo/get_world_properties "{}"
rosservice call /gazebo/get_model_properties "model_name: rover_test"
rostopic list | grep -E '^/imu$|^/laser/scan$|^/points_raw$'
```

Acceptance criteria for this phase:
- rover exists in `/gazebo/get_world_properties`
- one real LiDAR topic exists and publishes non-empty data
- one real IMU topic exists and publishes non-empty data

If this phase fails, do not launch FAST-LIVO2.

### Phase 3 - choose one real LiDAR path only
Do not chase Hokuyo, Velodyne, Livox emulation, and custom bridges all at once.
Choose the easiest proven path.

Recommended order:
1. `rplidar`-style ROS LaserScan path,
2. then `/laser/scan` -> `/points_raw` with `tools/scan_to_cloud.py`,
3. only then convert to `/livox/lidar` if you still need it.

Reason:
- the standalone `rplidar` model path is simpler to reason about,
- it gives a direct ROS topic,
- it reduces uncertainty before you bring Livox-format conversion back in.

### Phase 4 - solve ROS IMU explicitly
Treat real ROS IMU publication as its own task.
Do not assume PX4 native IMU plugins already satisfy the ROS side.

Acceptance criteria:
```bash
rostopic info /imu
rostopic hz /imu
rostopic echo -n 1 /imu
```

A real pass means:
- publisher present,
- stable rate,
- real message payload, not just an advertised topic.

### Phase 5 - only then reconnect the mapper
Once the real sensor topics are proven:
- real lidar -> `/points_raw`
- if needed, `/points_raw` -> `/livox/lidar`
- real imu -> `/livox/imu` or directly to FAST-LIVO2 config, depending on the chosen path
- rerun FAST-LIVO2

At that point, Step 3 becomes fully real rather than synthetic.

## What the agent should stop doing
- Stop treating old notes as truth if they were not reproduced.
- Stop patching only `rover.sdf` without deciding how to preserve the change.
- Stop changing mapper config before raw real topics are proven.
- Stop debugging more than one sensor path at once.
- Stop calling the task “done” just because synthetic Step 3 works.

## What the agent should produce next
A short status report with exactly four boxes:

1. Synthetic Step 3
- pass/fail
- evidence

2. Real rover LiDAR
- pass/fail
- exact topic name
- rate
- sample payload evidence

3. Real rover IMU
- pass/fail
- exact topic name
- rate
- sample payload evidence

4. Full real Step 3
- pass/fail
- if fail, single blocking reason only

That report will stop the drift.

## Submission advice if time runs short
The honest strong submission is:
- environment setup works,
- FAST-LIVO2 pipeline works,
- topic bridging works,
- synthetic end-to-end proof exists,
- real rover sensor integration remains the last unresolved gap.

That is much better than pretending the full real chain works when it does not.

## Official references checked
- FAST-LIVO2 official repository and README
- PX4 Gazebo classic official repository/README
- Gazebo ROS plugin documentation for `GazeboRosIMU` and `GazeboRosImuSensor`
