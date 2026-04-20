# Sage Advice 6

You are past the crash investigation stage.
Do not go backwards.

The current best truth is:
- the old rover Velodyne path was the crash source,
- the no-Velodyne + `rplidar` + ROS IMU rover is stable,
- real scan and real IMU now publish,
- the mapper path was already proven with synthetic inputs.

So the next task is clear:
- reconnect the real rover topics into the already-working Step 3 mapping chain.

## The new baseline
Use only this rover model now:
- `lib/PX4-Autopilot/Tools/sitl_gazebo/models/rover/rover_no_velodyne_rplidar_imu.sdf`

Do not re-open the old crashing Velodyne path.
Do not mix old rover variants into the final run.

## What is already proven
Upstream:
- real `/laser/scan` works,
- real `/imu` works,
- Gazebo stays stable.

Downstream:
- `/points_raw` -> `/livox/lidar` bridge path works,
- FAST-LIVO2 works and publishes `/cloud_registered` when fed valid input.

That means the only remaining job is the middle connection.

## The target chain
The full real Step 3 chain should now be:

```text
rover_no_velodyne_rplidar_imu.sdf
  -> /laser/scan
  -> tools/scan_to_cloud.py
  -> /points_raw
  -> tools/points_to_livox.py   (only if needed)
  -> /livox/lidar
  -> FAST-LIVO2
  -> /cloud_registered
```

And IMU should go either:

```text
/imu -> FAST-LIVO2 directly
```

or, if your current proven launch path expects Livox naming:

```text
/imu -> /livox/imu
```

Do not invent a third route.
Use the smallest change from the already-proven synthetic setup.

## Best practical approach
Reuse as much of the synthetic Step 3 setup as possible.

That means:
- keep `tools/points_to_livox.py` if the current FAST-LIVO2 launch expects `/livox/lidar`,
- replace only the fake source with the real rover source,
- keep the mapper launch/config stable unless a topic remap is strictly needed.

This is the shortest path to a real end-to-end proof.

## Exact plan

### Step 1 - run only the stable rover model
Acceptance:
- `/laser/scan` has non-zero rate,
- `/imu` has non-zero rate,
- Gazebo stays alive.

Required checks:
```bash
rostopic hz /laser/scan
rostopic echo -n 1 /laser/scan
rostopic hz /imu
rostopic echo -n 1 /imu
```

### Step 2 - bring scan into `/points_raw`
Run:
- `tools/scan_to_cloud.py`

Acceptance:
```bash
rostopic type /points_raw
rostopic hz /points_raw
rostopic echo -n 1 /points_raw
```

The only question here is whether the scan-to-cloud conversion is stable and non-empty.

### Step 3 - feed the lidar topic into the already-working mapper input path
If your proven synthetic path used `/livox/lidar`, keep that.
Run:
- `tools/points_to_livox.py`

Acceptance:
```bash
rostopic type /livox/lidar
rostopic hz /livox/lidar
rostopic echo -n 1 /livox/lidar
```

If FAST-LIVO2 can accept the direct point cloud path you are using, then keep it simpler and avoid unnecessary conversion. But do not change this unless the existing working mapping path forces you to.

### Step 4 - resolve IMU naming with the smallest possible change
The key question is simple:
- does the current working FAST-LIVO2 setup already accept `/imu`, or
- does it expect `/livox/imu`?

Choose the smaller change.

Best-practice preference:
- if the current mapper config can simply be pointed at `/imu`, do that,
- if changing config risks destabilizing the known-good launch, remap `/imu` to `/livox/imu` and keep the launch unchanged.

Do not refactor the whole launch for style reasons.

Acceptance:
```bash
rostopic hz /imu
# or if remapped
rostopic hz /livox/imu
```

### Step 5 - rerun FAST-LIVO2 with real topics
Now and only now start the mapper.

Acceptance for the final step:
```bash
rostopic hz /cloud_registered
rostopic echo -n 1 /cloud_registered
```

A real pass means:
- `/cloud_registered` exists,
- non-zero publish rate,
- non-empty cloud payload,
- no synthetic source in the loop.

## What not to do
- Do not reintroduce the old Velodyne block.
- Do not change multiple bridge scripts at once.
- Do not rewrite FAST-LIVO2 config unless the existing proven setup truly requires it.
- Do not mix fake and real sources in the same final proof.
- Do not declare success until `/cloud_registered` is coming from the real rover path.

## If something fails, localize it immediately
Use this logic:

- If `/laser/scan` fails: the rover model is still the blocker.
- If `/laser/scan` works but `/points_raw` fails: `scan_to_cloud.py` is the blocker.
- If `/points_raw` works but `/livox/lidar` fails: `points_to_livox.py` is the blocker.
- If lidar and imu both reach expected topics but `/cloud_registered` fails: FAST-LIVO2 topic/config mapping is the blocker.

This keeps the debugging bounded.

## What the next report should contain
Do not send a broad narrative.
Send a simple chain report:

- rover model used: exact file
- `/laser/scan`: pass/fail + rate
- `/imu`: pass/fail + rate
- `/points_raw`: pass/fail + rate
- `/livox/lidar`: pass/fail + rate or `not used`
- mapper input topics actually used: exact names
- `/cloud_registered`: pass/fail + rate
- final verdict: full real Step 3 pass/fail

## One-sentence mission
Take the stable `rover_no_velodyne_rplidar_imu.sdf`, replace the fake source with its real scan and IMU topics, and prove `/cloud_registered` from the real rover path without changing more than necessary.
