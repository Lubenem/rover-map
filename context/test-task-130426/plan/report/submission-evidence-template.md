# Submission Evidence Template

## Run Metadata
- run_date:
- run_time:
- timezone:
- operator:

## Environment
- repo_path: `~/projects/rover-map`
- docker_container: `rover-map`
- world_used:
- world_selection_mode: `primary|fallback|manual`
- rover_model_used: `/workspace/lib/PX4-Autopilot/Tools/sitl_gazebo/models/rover/rover_no_velodyne_rplidar_imu.sdf`
- mapper_blind_override: `/preprocess/blind=0.1`

## Command Set Used
- stack_start_command:
- drive_command:
- check_command:
- stack_stop_command:

## Topic Health Snapshot
- `/laser/scan` rate:
- `/imu` rate:
- `/livox/imu` rate:
- `/points_raw` width sample:
- `/livox/lidar` point_num sample:
- `/cloud_registered` width sample:
- `/cloud_registered` rate:

## Evidence Paths
- runtime_logs_dir:
- check_evidence_dir:
- check_summary_file:
- cloud_echo_file:
- livox_echo_file:

## Media Links (Fill Manually)
- video_recording_path_or_link:
- screenshot_gazebo_path_or_link:
- screenshot_rviz_path_or_link:

## Acceptance Checklist
- [ ] standard world used (`warehouse` preferred, `yosemite` fallback)
- [ ] rover motion visible in Gazebo
- [ ] RViz shows growing accumulated map
- [ ] submission_check reports all PASS
- [ ] no synthetic source used in final run

## Notes / Deviations
- fallback_reason_if_any:
- residual_risk:
