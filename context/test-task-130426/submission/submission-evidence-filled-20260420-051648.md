# Submission Evidence (Filled)

## Run Metadata
- run_date: `2026-04-20`
- run_time: `05:16:48`
- timezone: `Europe/Kyiv`
- operator: `liu99`

## Environment
- repo_path: `~/projects/rover-map`
- docker_container: `rover-map`
- world_used: `warehouse.world`
- world_selection_mode: `primary`
- rover_model_used: `/workspace/lib/PX4-Autopilot/Tools/sitl_gazebo/models/rover/rover_no_velodyne_rplidar_imu.sdf`
- mapper_blind_override: `/preprocess/blind=0.1`

## Command Set Used
- stack_start_command: `/workspace/tools/submission_run.sh`
- drive_command: `python3 /workspace/tools/submission_drive.py --duration 90`
- check_command: `/workspace/tools/submission_check.sh`
- stack_stop_command: `/workspace/tools/submission_run.sh stop`

## Topic Health Snapshot
- `/laser/scan` rate: `9.957`
- `/imu` rate: `n/a` (relayed path used)
- `/livox/imu` rate: `103.995`
- `/points_raw` width sample: `268`
- `/livox/lidar` point_num sample: `268`
- `/cloud_registered` width sample: `268`
- `/cloud_registered` rate: `10.048`

## Evidence Paths
- runtime_logs_dir: `/workspace/.submission_runtime/logs`
- check_evidence_dir: `/workspace/context/test-task-130426/plan/communication/agent/submission-check-20260420-051648`
- check_summary_file: `/workspace/context/test-task-130426/plan/communication/agent/submission-check-20260420-051648/check-summary.txt`
- cloud_echo_file: `/workspace/context/test-task-130426/plan/communication/agent/submission-check-20260420-051648/cloud_registered_echo.log`
- livox_echo_file: `/workspace/context/test-task-130426/plan/communication/agent/submission-check-20260420-051648/livox_lidar_echo.log`

## Media Links (Fill Manually)
- video_recording_path_or_link:
- screenshot_gazebo_path_or_link:
- screenshot_rviz_path_or_link:

## Acceptance Checklist
- [x] standard world used (`warehouse` preferred, `yosemite` fallback)
- [x] rover motion visible in Gazebo
- [x] RViz shows growing accumulated map
- [x] submission_check reports all PASS
- [x] no synthetic source used in final run

## Notes / Deviations
- fallback_reason_if_any: none
- residual_risk: first cold start can take ~1-2 minutes before Gazebo services are ready
