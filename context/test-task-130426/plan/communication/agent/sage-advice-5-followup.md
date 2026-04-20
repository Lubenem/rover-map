# Sage Advice 5 Follow-up (Clean Rerun)

Validation root:
- `/workspace/context/test-task-130426/plan/communication/agent/advice5-validation-20260417-055439`

Compact table:
- case 1: stable=`pass` / segfault=`no` / scan=`n/a` / imu=`n/a`
- case 2: stable=`pass` / segfault=`no` / scan=`pass (~9.973 Hz)` / imu=`n/a`
- case 3: stable=`pass` / segfault=`no` / scan=`n/a` / imu=`pass (~102.042 Hz)`
- case 4: stable=`pass` / segfault=`no` / scan=`pass (~9.994 Hz)` / imu=`pass (~101.596 Hz)`
- chosen final baseline: `rover_no_velodyne_rplidar_imu.sdf`

Notes:
- `summary.txt` now uses a fixed schema and includes `segfault=`.
- `core.log` in each case contains no `Segmentation fault` string.
