# Final Submission Message

Hello,
Please find my completed FAST-LIVO2 test task submission.

## Summary
- Objective completed: FAST-LIVO2 running on PX4 + Gazebo rover, driven through standard map, point cloud visible in RViz.
- Rover model: `rover_no_velodyne_rplidar_imu.sdf`
- World: `warehouse.world`
- Pipeline: `/laser/scan -> /points_raw -> /livox/lidar`, `/imu -> /livox/imu`, output `/cloud_registered`
- Runtime override: `/preprocess/blind=0.1`

## Media
- Demo video: `https://drive.google.com/file/d/1MLDMqBAZNfSqWKYbwTeoPaQuRdHAEYTY/view?usp=sharing`
- Screenshots: not provided (video-only submission)

## Note
- Rover motion in demo is deterministic via `tools/submission_drive.py`.

Thank you for your review.
