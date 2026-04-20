# Step 2 – Baseline Validation (PX4 + Gazebo + ROS topics)

Goal
- Run PX4 SITL rover in Gazebo and confirm ROS topics for IMU and lidar exist and publish at stable rates.

Tmux layout (session: `run-ros`)
- `roscore`  : run `roscore`
- `sim`      : launch PX4+Gazebo
- `sensors`  : inspect ROS topics/rates
- `gzcheck`  : optional Gazebo transport checks (`gz topic -l`, etc.)
- `map`/`bag`/`topics` : spare shells (unused now)

One-time prerequisites (already baked into image)
- Fix Gazebo plugin paths: `Tools/setup_gazebo.bash` now appends `/usr/lib/x86_64-linux-gnu/gazebo-11/plugins` and `/usr/share/gazebo-11/models` to ensure `libgazebo_ros_laser.so` loads.
- Rover model publishes ROS IMU + LaserScan: edits in `Tools/sitl_gazebo/models/rover/rover.sdf` (ROS IMU + ROS laser plugins).

Startup sequence (repeatable)
1) Host shell: `cd ~/projects/rover-map && make docker-up` (if not already) then `make docker-shell` to get a container shell.
2) Inside container, start tmux session `run-ros` if not present: `tmux new -s run-ros` (already running in our case).

Window commands (run in this order)
- `roscore` window:
  ```bash
  source /opt/ros/noetic/setup.bash
  roscore
  ```

- `sim` window (PX4 + Gazebo):
  ```bash
  source /opt/ros/noetic/setup.bash
  cd /workspace/lib/PX4-Autopilot
  make px4_sitl gazebo_rover
  ```
  Notes: Gazebo GUI will pop; physics auto-unpaused; uses `rover.sdf` with ROS IMU/Laser.

- `sensors` window (validation):
  ```bash
  source /opt/ros/noetic/setup.bash
  rostopic list | grep -Ei "^/imu$|^/laser/scan$"
  timeout 4 rostopic hz /imu       # expect ~83 Hz
  timeout 4 rostopic hz /laser/scan # expect ~10 Hz
  ```
  Optional samples:
  ```bash
  rostopic echo -n 3 /imu
  rostopic echo -n 3 /laser/scan
  ```

What we validated
- `/imu` publishes at ~83 Hz from `gazebo_ros_imu`.
- `/laser/scan` publishes at ~10 Hz from `gazebo_ros_laser` on the rover model.
- Gazebo ROS API plugin is loaded; physics unpaused.

If something breaks
- Ensure `roscore` is up before starting `make px4_sitl gazebo_rover`.
- If `/laser/scan` disappears: restart sim after confirming `Tools/setup_gazebo.bash` contains the default Gazebo paths.
- To clear stuck sim: in `sim` window press Ctrl+C, then rerun the command block above.
