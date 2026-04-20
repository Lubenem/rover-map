# Message to the other agent

You do not need more random experiments. You need a clean chain of proof.

## The missing links in our process

1. We mixed up three different artifacts as if they were the same thing.
- `lib/PX4-Autopilot/Tools/sitl_gazebo/models/rover/rover.sdf.jinja` = tracked template.
- `lib/PX4-Autopilot/Tools/sitl_gazebo/models/rover/rover.sdf` = runtime file PX4 actually spawns.
- `lib/PX4-Autopilot/Tools/sitl_gazebo/models/rover/rover.sdf.last_generated` = last clean generated snapshot.
- We added ROS IMU + Hokuyo edits directly to `rover.sdf`, but the tracked diff is mainly in `rover.sdf.jinja`. That means our current behavior and our versioned source of truth are drifting apart.

2. We treated PX4's built-in IMU plugin as if it were a ROS topic source.
- It is not. `lib/PX4-Autopilot/Tools/sitl_gazebo/src/gazebo_imu_plugin.cpp` publishes on Gazebo transport, not ROS.
- That explains why the baseline rover does not give a ROS `/imu` topic by itself.

3. We assumed the current sensor edits were working without isolating them.
- In a clean isolated Gazebo check, both the baseline rover (`rover.sdf.last_generated`) and the current modified rover (`rover.sdf`) spawn successfully.
- So “rover is not spawning” is not the main verified blocker.
- The real blocker is sensor publication.

4. We never separated “Gazebo can publish this sensor” from “the rover integration is correct”.
- Standalone `rplidar` works and publishes `/laser/scan` at ~10 Hz.
- The same effect is not currently proven on the rover.
- Therefore the problem is the rover integration method, not Gazebo ROS laser support in general.

5. We kept building bridges before proving raw inputs exist.
- FAST-LIVO2 wiring is downstream.
- First prove real sensor traffic from the rover.
- Only then bridge to `/points_raw`, `/livox/lidar`, or FAST-LIVO2 input topics.

## What I verified locally

### 1) Rover spawn is not the core problem
In an isolated ROS/Gazebo session, these both spawn successfully:
- `lib/PX4-Autopilot/Tools/sitl_gazebo/models/rover/rover.sdf.last_generated`
- `lib/PX4-Autopilot/Tools/sitl_gazebo/models/rover/rover.sdf`

That means the current story “model never spawns” is not the most reliable working theory.

### 2) The current Hokuyo/Laser edit is not giving us a ROS scan
The current manual edit added an `<include>` for `model://hokuyo` inside `rover.sdf`.
In a clean check, the modified rover still does **not** expose `/laser/scan`.
Treat that edit as non-working.

### 3) The baseline PX4 IMU path is not a ROS IMU path
The built-in PX4 `gazebo_imu_plugin.so` uses Gazebo transport IMU messages for PX4 internals.
Do not expect that plugin alone to produce ROS `/imu`.

### 4) The added `gazebo_ros_imu_sensor.so` change is not yet proven
The current modified rover advertises `/imu` in some runs, but we do **not** have a clean proof that it publishes usable messages from the rover.
So do not build the rest of the pipeline on that assumption.

### 5) `rplidar` is proven in isolation
This file works as a ROS laser source:
- `lib/PX4-Autopilot/Tools/sitl_gazebo/models/rplidar/model.sdf`

And this reference integration also works:
- `lib/PX4-Autopilot/Tools/sitl_gazebo/models/iris_rplidar/iris_rplidar.sdf`

That is the best reference for adding a 2D ROS laser to the rover if we go that route.

## What you should do next

### Rule 1: stop editing the wrong file
If you change rover sensors, do one of these deliberately:
- patch `rover.sdf.jinja` and regenerate/track the result, or
- keep a separate explicitly named test file and spawn that on purpose.

Do **not** keep making manual edits only in `rover.sdf` and then forget they are outside the tracked template.

### Rule 2: use an isolated validation loop
Before touching the full PX4 launch, validate in a clean session with separate ports so you are not fighting old ROS/Gazebo state.

Use this pattern:
```bash
source /opt/ros/noetic/setup.bash
source /workspace/lib/PX4-Autopilot/Tools/setup_gazebo.bash /workspace/lib/PX4-Autopilot /workspace/lib/PX4-Autopilot/build/px4_sitl_default
export ROS_MASTER_URI=http://127.0.0.1:11411
export GAZEBO_MASTER_URI=http://127.0.0.1:11445
export GAZEBO_MODEL_DATABASE_URI=""
roslaunch gazebo_ros empty_world.launch \
  world_name:=/workspace/lib/PX4-Autopilot/Tools/sitl_gazebo/worlds/empty.world \
  gui:=false pause:=false use_sim_time:=false
```

Then in a second shell:
```bash
source /opt/ros/noetic/setup.bash
export ROS_MASTER_URI=http://127.0.0.1:11411
export GAZEBO_MASTER_URI=http://127.0.0.1:11445
rosrun gazebo_ros spawn_model -sdf -file /workspace/lib/PX4-Autopilot/Tools/sitl_gazebo/models/rover/rover.sdf.last_generated -model rover_test
rosservice call /gazebo/get_world_properties "{}"
rosservice call /gazebo/get_model_properties "model_name: rover_test"
rostopic list | grep -E '^/imu$|^/laser/scan$|^/points_raw$'
```

If this loop is not green, do not go back to full PX4 yet.

### Rule 3: pick one sensor path and prove it end to end
Do not chase three alternatives at once.

#### Path A - fastest proven ROS laser path
- Use `rplidar` as the laser source.
- Copy the integration pattern from `iris_rplidar.sdf`.
- Validate `/laser/scan` first.
- If it works, then use `tools/scan_to_cloud.py` to turn `/laser/scan` into `/points_raw`.

This is not elegant, but it is concrete and already partly proven.

#### Path B - keep the rover's existing 3D lidar only if you can prove it
- Do **not** assume `/points_raw` is real until you see it in a clean run.
- If `/points_raw` is absent, stop treating the built-in velodyne block as solved.

#### Path C - ROS IMU
- Stop assuming PX4's `gazebo_imu_plugin.so` gives ROS `/imu`.
- Either add a proven ROS IMU plugin deliberately, or bridge from a source that is already known to be ROS-visible.
- The current `gazebo_ros_imu_sensor.so` experiment is not yet trustworthy enough to be the foundation.

## The safest recovery sequence

1. Freeze a clean rover baseline.
- Use `rover.sdf.last_generated` as the known-good reference.
- Compare against current `rover.sdf` before each experiment.

2. Prove one working LiDAR source.
- First choice: standalone `rplidar` / `iris_rplidar` reference.
- Acceptance: `/laser/scan` exists and `rostopic hz /laser/scan` is non-zero.

3. Prove one working ROS IMU source.
- Acceptance: `/imu` exists and `rostopic hz /imu` is non-zero.

4. Only after both exist, do the bridge wiring.
- `/laser/scan` -> `tools/scan_to_cloud.py` -> `/points_raw`
- `/points_raw` -> `tools/points_to_livox.py` -> `/livox/lidar` if needed
- keep IMU on a clean ROS topic

5. Only after raw topics are proven, run FAST-LIVO2.
- Otherwise you are debugging the mapper with fake assumptions.

## What to stop doing
- Stop trusting old notes that say `/imu` and `/laser/scan` were already solved.
- Stop treating “topic exists in `rostopic list`” as equivalent to “messages are flowing”.
- Stop debugging FAST-LIVO2 before sensor publication is verified.
- Stop editing only `rover.sdf` without also deciding how that change will be preserved.

## If time is running out
Submit the task as a disciplined partial result, not as a chaotic almost-working system.
The strongest partial story is:
- reproducible Docker/ROS/PX4 environment,
- clean explanation of the sensor gap,
- proven standalone ROS laser publication,
- documented bridge scripts in `tools/scan_to_cloud.py` and `tools/points_to_livox.py`,
- explicit note that the remaining blocker is a verified ROS IMU + final rover sensor integration.

That is a credible engineering result.
