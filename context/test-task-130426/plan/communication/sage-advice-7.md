# Sage Advice 7

Mission now is not more debugging.
Mission is **submission readiness** against the exact task text:
- run FAST-LIVO2 on a PX4 + Gazebo rover with LiDAR,
- drive through a standard map,
- show point cloud in RViz.

The user will capture screenshots/video manually.
Your job is to prepare a deterministic run scenario and operator guide so capture is easy and repeatable.

## Ground truth from current evidence
- Real sensor chain is proven with `rover_no_velodyne_rplidar_imu.sdf`.
- End-to-end map output is proven (`/cloud_registered` pass) when using:
  - `/laser/scan -> /points_raw -> /livox/lidar`
  - IMU path to `/livox/imu`
  - FAST-LIVO2 with `preprocess.blind=0.1`.

Do not reopen old crash investigation.
Do not reintroduce Velodyne path.

## What to produce now (concrete deliverables)
Create these assets in this repo:

1) `tools/submission_run.sh`
- One command to bring up the final stack for submission demo.
- Must include:
  - Gazebo world set to a **standard map** (primary + fallback defined).
  - Stable rover model spawn: `rover_no_velodyne_rplidar_imu.sdf`.
  - bridges (`scan_to_cloud.py`, `points_to_livox.py`, IMU relay).
  - FAST-LIVO2 start with `preprocess.blind=0.1` applied explicitly.
  - Optional RViz launch flag (default on for user capture).

2) `tools/submission_drive.py`
- Deterministic rover motion helper for demo capture.
- Purpose: ensure map visibly grows while rover moves.
- Keep simple and reliable (fixed route/velocity profile, fixed duration).
- Log timestamps and route phase changes so run is auditable.

3) `tools/submission_check.sh`
- Fast readiness checker with PASS/FAIL table:
  - `/laser/scan` rate > 0
  - `/imu` or `/livox/imu` rate > 0
  - `/points_raw` width > 0
  - `/livox/lidar` point_num > 0
  - `/cloud_registered` width > 0 and rate > 0
- Write outputs into a timestamped evidence folder under `context/test-task-130426/plan/communication/agent/`.

4) `context/test-task-130426/plan/report/submission-operator-guide.md`
- Human-facing guide for the user (who records media).
- Must be step-by-step with exact commands and expected outputs.
- Must include a timed capture script (what to record at minute 0/1/2/3).

5) `context/test-task-130426/plan/report/submission-evidence-template.md`
- Fill-in template for final package:
  - run date/time,
  - world used,
  - model used,
  - command set,
  - topic rates,
  - cloud width samples,
  - file paths to logs,
  - placeholders where user inserts screenshot/video links.

## Standard map rule
Primary world should be one of PX4 sitl_gazebo standard worlds with real geometry.
Recommended order:
1. `warehouse.world` (primary)
2. `yosemite.world` (fallback)

Do not use empty world + synthetic wall in final submission path unless both standard worlds fail.
If fallback is needed, document why.

## RViz capture scenario (what user should do)
In operator guide, include this exact capture sequence:
1. Start recording.
2. Show terminal where `submission_check.sh` reports all PASS.
3. Show Gazebo rover moving in standard world.
4. Show RViz with `/cloud_registered` map growing.
5. Stop recording after 60-120s of continuous growth.
6. Take 2 screenshots:
   - Gazebo world with rover in motion.
   - RViz map with visible accumulated cloud.

## Hard acceptance gate before handing to user
Do not ask user to record until all pass:
- real rover model used (`rover_no_velodyne_rplidar_imu.sdf`),
- standard world used,
- rover motion happens during run,
- `/cloud_registered` stays non-empty during motion,
- single command path documented and repeatable.

## Reporting format back to me
Reply with a compact "submission-ready" packet:
- paths of all new scripts/docs,
- one command to start stack,
- one command to start motion,
- one command to run checks,
- exact evidence directory from latest dry run,
- any residual risk in one bullet only.

## One-sentence objective
Turn the proven technical fix into a **one-run, capture-ready demo flow** so the user can record final evidence for task submission without improvisation.
