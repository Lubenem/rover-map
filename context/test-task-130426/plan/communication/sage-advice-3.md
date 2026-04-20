# Sage Advice 3

Focus the next round on the real blocker.

The blocker is no longer FAST-LIVO2.
The blocker is a Gazebo crash in the real rover sensor stack.

## What the agent should believe now
- Synthetic Step 3 is already good enough to prove the mapper path.
- Real Step 3 fails because Gazebo dies before stable rover sensor traffic exists.
- Therefore the correct task is: identify the single rover sensor/plugin change that causes `gzserver` to segfault.

## The goal of the next session
Produce one sentence:
- "Gazebo crashes when this exact plugin or sensor block is present."

Not two causes.
Not five theories.
One exact trigger.

## The working method
Use bisection, not intuition.

### Baseline
Start only from:
- `lib/PX4-Autopilot/Tools/sitl_gazebo/models/rover/rover.sdf.last_generated`

Treat that as the clean baseline.
Do not start from the hand-edited `rover.sdf` unless the point is to compare against it.

### Rule
Add back one change at a time.
After each change, do only one isolated Gazebo spawn test.

If Gazebo survives, keep the change.
If Gazebo segfaults, you found the suspect.

## The likely suspects to test first
Test in this order.

1. ROS IMU sensor block added into `rover.sdf`
- `libgazebo_ros_imu_sensor.so`
- This is the strongest suspect because `/imu` appears but no usable traffic arrives, and the crash report mentions IMU plugin setup lines.

2. Any manual lidar include added directly into the rover
- especially the Hokuyo-style include path
- treat this as untrusted until proven in isolation

3. Combined sensor stack interactions
- IMU plugin + lidar include together
- only test this after each single piece has been tested alone

Do not start with combined changes.

## Required isolation loop
Use the same clean loop every time.
Do not mix in PX4 full launch until the crash is understood.

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
rosrun gazebo_ros spawn_model -sdf -file /tmp/test_rover.sdf -model rover_test
rosservice call /gazebo/get_world_properties "{}"
rostopic list | grep -E '^/imu$|^/laser/scan$|^/points_raw$|^/clock$'
```

Acceptance for "no crash":
- `/gazebo/get_world_properties` still answers
- `/clock` keeps moving
- `gzserver` stays alive for at least 15-30 seconds after spawn

## The exact experiment plan

### Experiment 0
- Spawn `rover.sdf.last_generated` unchanged.
- Expected result: no crash.
- Record: pass/fail.

### Experiment 1
- Take baseline.
- Add only the ROS IMU sensor block.
- Spawn.
- Record:
  - does Gazebo crash?
  - does `/imu` appear?
  - does `/imu` actually publish messages?

### Experiment 2
- Revert to baseline.
- Add only the lidar include block.
- Spawn.
- Record:
  - does Gazebo crash?
  - does `/laser/scan` or `/points_raw` appear?
  - does the topic carry non-empty messages?

### Experiment 3
- Only if Experiments 1 and 2 each survive alone.
- Combine them.
- Spawn.
- Record whether the interaction causes the crash.

This will tell you whether the failure is:
- one bad plugin,
- one bad sensor include,
- or one bad interaction.

## What the agent must capture for each experiment
Use the same four fields every time:

1. file used
2. exact edit added
3. result: pass / segfault / no topic / empty topic
4. minimal evidence

Example:
- file: `/tmp/test_rover_imu_only.sdf`
- edit: added `libgazebo_ros_imu_sensor.so`
- result: segfault
- evidence: `process[gazebo-2] has died ... exit code 139`

## What not to do
- Do not touch FAST-LIVO2 during this loop.
- Do not run the fake sensor source during this loop.
- Do not change two rover sensor blocks at once.
- Do not use old notes as evidence unless reproduced in this exact isolated loop.
- Do not patch only `rover.sdf` and forget how the change will be preserved.

## If the IMU-only test is the crash trigger
Then the next action is simple:
- stop using that plugin block for now,
- document it as the immediate blocker,
- try an alternative ROS IMU publication strategy only after the crash trigger is confirmed.

## If the lidar-only test is the crash trigger
Then stop trying to force that rover lidar path.
Use the already simpler path:
- prove standalone `rplidar`,
- then decide whether to mount it onto rover cleanly,
- or keep Step 3 submission partial with the synthetic proof already working.

## If neither single test crashes, but the combined test crashes
Then the issue is plugin interaction.
At that point the agent should stop broad debugging and report exactly that:
- each sensor block survives alone,
- the combined stack crashes Gazebo,
- full real Step 3 is blocked by rover plugin interaction.

## The only output needed next
I do not need another broad summary.
I need a tiny table like this:

- baseline: pass/fail
- imu-only: pass/fail
- lidar-only: pass/fail
- combined: pass/fail
- first crash trigger: ______

Once that table exists, the problem becomes manageable.
