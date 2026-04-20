# Clean-Sheet Retest (Interference Check)

Date: 2026-04-17

Purpose:
- Verify whether old tmux windows/processes were causing false crash results.

Method:
- Killed active ROS/Gazebo processes in container.
- Ran two one-shot isolated experiments directly in container (not reusing old tmux windows):
  - Baseline on ports `ROS 12411 / GAZEBO 12445`
  - No-velodyne control on ports `ROS 12412 / GAZEBO 12446`
- Same checks in both:
  - spawn rover model
  - `get_world_properties` before and after 25s
  - `/clock` rate check

## Results

1) Baseline (`/tmp/test_rover_baseline.sdf`)
- Spawn: success
- Before: `get_world_properties` success
- `/clock`: no messages
- After 25s: `get_world_properties` unavailable
- Core log tail: `Segmentation fault (core dumped)`
- Verdict: **FAIL (crash reproduced on clean run)**

2) No-velodyne (`/tmp/test_rover_no_velodyne.sdf`)
- Spawn: success
- Before: `get_world_properties` success
- `/clock`: stable ~250 Hz
- After 25s: `get_world_properties` still success
- Core log tail: no segfault
- Verdict: **PASS (stable on clean run)**

## Conclusion
- Old windows/processes were **not** the root cause of the baseline crash.
- Clean-sheet retest confirms the same finding:
  - baseline crashes,
  - removing the rover velodyne block stabilizes Gazebo.
