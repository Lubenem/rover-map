# Sage Advice 4

You have the root cause now.
Use it.

The real blocker is confirmed:
- the rover's built-in Velodyne block is crashing Gazebo,
- the crash reproduces on a clean run,
- removing only that block makes the rover stable.

So stop treating this as a vague sensor problem.
It is now a concrete model/plugin mismatch problem.

## What is true now

### Confirmed root cause
The crash trigger is the rover Velodyne block:
- `<sensor name="velodyne" type="gpu_ray">`
- plugin `libgazebo_ros_velodyne_laser.so`

And the key log clue is:
- `RayPlugin requires a Ray Sensor as its parent`

That is a strong sign that the plugin and sensor type do not agree.
The working assumption should now be:
- current rover Velodyne block is invalid for this plugin/runtime combination.

## What this means for the next move
Do not debug everything.
Do not keep the crashing Velodyne block in the loop.

Your new baseline is:
- rover model with the entire Velodyne link/sensor/joint removed
- this is the only baseline that is currently proven stable

## The correct strategy now
You need one stable real rover LiDAR path.
Not the original crashing one.
Not three experimental ones.
One.

## Recommended path

### Path A - fastest practical recovery
Use the stable no-Velodyne rover and add a proven ROS LiDAR path.

Why this is the best choice:
- it avoids the known crash trigger,
- it is simpler than rescuing the current 3D Velodyne setup,
- it gets you back to real rover sensor work faster.

The simplest candidate is the known-good ROS laser model path already proven elsewhere:
- `rplidar`-style LaserScan source

Target sequence:
1. keep rover stable without Velodyne,
2. mount or attach one proven LiDAR source,
3. verify live ROS topic traffic,
4. convert only if needed,
5. reconnect FAST-LIVO2.

## What not to do next
- Do not keep testing the crashing Velodyne block as if it might randomly start working.
- Do not re-open FAST-LIVO2 debugging.
- Do not combine multiple new sensor ideas in one run.
- Do not edit only `rover.sdf` without knowing how the result will be preserved.

## Immediate experiment plan

### Step 1 - freeze the stable baseline
Create or preserve one explicit stable rover file, for example:
- `rover_no_velodyne.sdf`

That file should be:
- baseline rover from `rover.sdf.last_generated`
- with only the Velodyne link/sensor/joint removed
- nothing else changed

This is now the reference model for further work.

Acceptance:
- spawn succeeds,
- `/clock` stays alive,
- `/gazebo/get_world_properties` still works after 25-30 seconds,
- no `exit code 139`.

### Step 2 - prove one real LiDAR source on that stable rover
Add exactly one LiDAR integration path.
Only one.

Suggested order:
1. attach a proven `rplidar`-style source,
2. verify `/laser/scan`,
3. if needed, bridge `/laser/scan` to `/points_raw` with `tools/scan_to_cloud.py`.

Acceptance:
- `/laser/scan` exists,
- `rostopic hz /laser/scan` is non-zero,
- `rostopic echo -n 1 /laser/scan` returns payload,
- Gazebo remains stable.

### Step 3 - solve IMU separately
Do not combine the IMU fix into the LiDAR test unless the rover is already stable.

Acceptance for IMU:
- `/imu` exists,
- non-zero rate,
- real payload from `rostopic echo -n 1 /imu`.

### Step 4 - reconnect the mapping stack only after both are proven
Order:
1. real rover LiDAR topic proven,
2. real rover IMU topic proven,
3. bridge to `/points_raw` or `/livox/lidar` only if needed,
4. rerun FAST-LIVO2.

## If you want the shortest possible delivery path
Be pragmatic.
You do not need to save the original crashing Velodyne design today.
You need a stable real rover sensor source.

So the best practical move is:
- abandon the crashing rover Velodyne block for now,
- switch to stable rover + proven alternative LiDAR source,
- get real ROS topics flowing,
- then plug that into the already-working mapping path.

## What the next report should contain
Do not send another long narrative.
Send only this:

- stable no-velodyne rover: pass/fail
- attached LiDAR source used: exact file/plugin/model name
- `/laser/scan` or replacement topic: pass/fail + rate
- `/imu`: pass/fail + rate
- Gazebo stability after 30s: pass/fail
- ready to reconnect FAST-LIVO2: yes/no

## One-sentence mission
Use the no-Velodyne rover as the new baseline, add one proven non-crashing LiDAR source, and do not return to FAST-LIVO2 until Gazebo stays stable and real rover topics actually publish.
