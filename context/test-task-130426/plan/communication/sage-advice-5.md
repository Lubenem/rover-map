# Sage Advice 5

The technical direction is probably correct.
But your proof set is not clean enough yet.

Right now the validation folder says two different things at once:
- `summary.txt` says the advice-4 models are stable and passing,
- `core.log` still shows `Segmentation fault (core dumped)`.

That makes the folder non-trustworthy as final evidence.
Do not argue from ambiguous artifacts.
Clean them up once, properly, then move on.

## What you should assume
- The no-Velodyne strategy is still the best lead.
- The `rplidar` + ROS IMU path probably works.
- But until the logs and summaries agree, you do not yet have a defensible final proof.

## The goal now
Produce one clean evidence set where each case has exactly one truth.

For each case, the artifacts must agree on:
- spawn success,
- whether Gazebo stayed alive,
- whether `/clock` stayed alive,
- whether scan traffic existed,
- whether IMU traffic existed,
- whether a segfault happened.

## What is wrong with the current folder
The mismatch is simple:
- `summary.txt` reports `stable_30=pass` and `core_alive=yes`,
- but `core.log` still contains `Segmentation fault (core dumped)`.

That usually means one of two things:
1. old `core.log` content was reused or appended,
2. summary values were generated from a different run than the saved logs.

Either way, the result is the same:
- the evidence bundle is not final-quality.

## What to do next

### Step 1 - throw away mixed evidence, not the models
Keep the model files.
Do not keep trusting the current mixed logs.

The models of interest are:
- `rover_no_velodyne.sdf`
- `rover_no_velodyne_rplidar.sdf`
- `rover_no_velodyne_imu.sdf`
- `rover_no_velodyne_rplidar_imu.sdf`

Those are still the right set to validate.

### Step 2 - rerun each case from a clean slate
For each case:
- remove the old case output directory first, or create a brand-new timestamped directory,
- write logs with truncation, not append,
- do not reuse old tmux windows,
- kill old ROS/Gazebo processes before starting.

Minimum required per case:
- `spawn.log`
- `core.log`
- `summary.txt`
- `scan_echo.log` only if scan exists
- `imu_echo.log` only if IMU exists

### Step 3 - add one explicit field the current summaries are missing
Every `summary.txt` must contain:
- `segfault=yes` or `segfault=no`

And that field must be derived directly from the same `core.log` saved for that case.

This is the key missing link.

### Step 4 - use one fixed summary schema
For every case, write the same fields in the same order:
```text
case=
model=
world_up=
spawn_ok=
clock_rate=
scan_status=
scan_rate=
imu_status=
imu_rate=
stable_30=
core_alive=
segfault=
```

No custom wording.
No interpretation.
Only measured facts.

### Step 5 - define pass/fail mechanically
Use these rules:

`spawn_ok=pass` if spawn returns success.

`stable_30=pass` only if all are true:
- `gzserver` still alive after 30s,
- `/gazebo/get_world_properties` still responds after 30s,
- `/clock` still publishes after 30s,
- `segfault=no`.

`scan_status=pass` only if:
- topic exists,
- non-zero rate,
- `rostopic echo -n 1` returns payload.

`imu_status=pass` only if:
- topic exists,
- non-zero rate,
- `rostopic echo -n 1` returns payload.

This removes narrative ambiguity.

## The four cases to rerun

### Case 1
- model: `rover_no_velodyne.sdf`
- expected: stable, no scan, no imu unless explicitly added

### Case 2
- model: `rover_no_velodyne_rplidar.sdf`
- expected: stable, scan pass

### Case 3
- model: `rover_no_velodyne_imu.sdf`
- expected: stable, imu pass

### Case 4
- model: `rover_no_velodyne_rplidar_imu.sdf`
- expected: stable, scan pass, imu pass

## What to conclude if the rerun matches the summaries
If the clean rerun shows:
- Case 1 stable,
- Case 2 stable + scan,
- Case 3 stable + imu,
- Case 4 stable + scan + imu,
- and `segfault=no` everywhere,

then you are done with the Gazebo sensor-stability problem.

At that point the next move is obvious:
- use `rover_no_velodyne_rplidar_imu.sdf` as the new real-sensor rover baseline,
- reconnect the already-proven FAST-LIVO2 path,
- stop spending time on the old crashing Velodyne block.

## What to conclude if the rerun still shows real segfaults
Then the summaries were wrong, and you are not done.
In that case:
- trust the logs, not the optimistic summaries,
- identify which of the four cases still crashes,
- and continue from the last confirmed stable case only.

## The exact output needed after rerun
Do not send a long explanation.
Send one compact table:

- case 1: stable / segfault / scan / imu
- case 2: stable / segfault / scan / imu
- case 3: stable / segfault / scan / imu
- case 4: stable / segfault / scan / imu
- chosen final baseline: ______

## One-sentence mission
Rebuild the validation folder so every summary and log agrees, then either promote `rover_no_velodyne_rplidar_imu.sdf` to the new real-sensor baseline or identify the last case that still truly crashes.
