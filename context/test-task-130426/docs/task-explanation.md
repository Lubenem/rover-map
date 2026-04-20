# Task Explanation (Beginner-Friendly)

## 0) Like You Are 5: What Is This Task?
Imagine your robot car is wearing:
- eyes (`camera`)
- ears (`LiDAR`)
- balance sensor (`IMU`)

`FAST-LIVO2` is the robot brain that combines those sensors and draws a 3D map while the robot moves.

Your task message means:
1. Start a robot in simulation (PX4 + Gazebo).
2. Move it around a map (forest or any standard world).
3. Feed sensor data into FAST-LIVO2.
4. See a growing 3D point cloud map in RViz.

## 1) Important Reality Check From This Repo
This repository is **ROS1 (catkin)**, not ROS2-native:
- README builds with `catkin_make` and runs with `roslaunch` ([README.md](/home/liu99/projects/fast-livo2/README.md:88), [README.md](/home/liu99/projects/fast-livo2/README.md:103)).
- Build system uses `find_package(catkin ...)` ([CMakeLists.txt](/home/liu99/projects/fast-livo2/CMakeLists.txt:79)).
- Package depends on ROS1 packages (`roscpp`, `rospy`, `tf`, etc.) ([package.xml](/home/liu99/projects/fast-livo2/package.xml:19)).

So your intuition about ROS2 is normal, but this specific codebase is from the ROS1 world.

## 2) What FAST-LIVO2 Expects (From Code)
Inputs (topics):
- LiDAR topic (`common/lid_topic`)
- IMU topic (`common/imu_topic`)
- Image topic (`common/img_topic`)
  ([LIVMapper.cpp](/home/liu99/projects/fast-livo2/src/LIVMapper.cpp:52), [LIVMapper.cpp](/home/liu99/projects/fast-livo2/src/LIVMapper.cpp:57))

It subscribes here:
- LiDAR / IMU / image subscribers ([LIVMapper.cpp](/home/liu99/projects/fast-livo2/src/LIVMapper.cpp:192))

Main outputs you care about:
- Point cloud: `/cloud_registered`
- Odometry/path: `/aft_mapped_to_init`, `/path`
  ([LIVMapper.cpp](/home/liu99/projects/fast-livo2/src/LIVMapper.cpp:200))

It can run in 3 modes:
- `LIVO` (LiDAR + IMU + camera)
- `ONLY_LIO` (LiDAR + IMU)
- `ONLY_LO` (LiDAR only)
  ([LIVMapper.cpp](/home/liu99/projects/fast-livo2/src/LIVMapper.cpp:162), [common_lib.h](/home/liu99/projects/fast-livo2/include/common_lib.h:48))

This is great for your task: if your simulator gives LiDAR + IMU but no camera, you can still run `ONLY_LIO`.

## 3) Direct Answers To Your 3 Questions

### 1. What should I do? What should I install?
Use this sequence:

#### Step A: Choose a compatible environment first (most important)
Your laptop is `Pop!_OS 24.04`. On this OS, ROS1 Noetic is not a normal native path.

Recommended for this task:
- Use a **VM** (or Docker) with **Ubuntu 20.04 + ROS1 Noetic**.
- Keep FAST-LIVO2 and PX4 simulation in that ROS1-compatible environment.

Why:
- FAST-LIVO2 README targets Ubuntu 18.04-20.04 + ROS1 ([README.md](/home/liu99/projects/fast-livo2/README.md:51)).
- ROS Noetic lifecycle is May 2020 to May 2025 (REP-0003).
- ROS1 bridging on Ubuntu 24.04 is not supported (ros1_bridge docs).

#### Step B: Install FAST-LIVO2 dependencies in that VM
Inside Ubuntu 20.04 ROS1 environment, install/build:
- ROS1 Noetic desktop
- PCL, Eigen, OpenCV
- Sophus (the commit in README)
- `rpg_vikit`
- FAST-LIVO2 with `catkin_make`

Example baseline commands (inside Ubuntu 20.04 VM):

```bash
# ROS + common libs
sudo apt update
sudo apt install -y \
  ros-noetic-desktop-full \
  ros-noetic-pcl-ros \
  ros-noetic-cv-bridge \
  ros-noetic-image-transport \
  ros-noetic-tf \
  ros-noetic-eigen-conversions \
  ros-noetic-rviz \
  libpcl-dev libeigen3-dev libopencv-dev \
  build-essential cmake git python3-catkin-tools

# Sophus (repo-recommended commit)
git clone https://github.com/strasdat/Sophus.git
cd Sophus && git checkout a621ff
mkdir -p build && cd build
cmake ..
make -j$(nproc)
sudo make install
```

Then build workspace:

```bash
source /opt/ros/noetic/setup.bash
mkdir -p ~/catkin_ws/src
cd ~/catkin_ws/src
git clone https://github.com/xuankuzcr/rpg_vikit.git
git clone https://github.com/hku-mars/FAST-LIVO2.git fast-livo2
cd ~/catkin_ws
catkin_make
source devel/setup.bash
```

Repo references:
- Sophus + vikit + catkin build instructions: [README.md](/home/liu99/projects/fast-livo2/README.md:63)

#### Step C: Validate FAST-LIVO2 alone first (easy sanity check)
Before PX4/Gazebo integration, run the provided bag workflow:
- `roslaunch fast_livo mapping_avia.launch`
- `rosbag play ...`
  ([README.md](/home/liu99/projects/fast-livo2/README.md:103))

If this works, your FAST-LIVO2 side is healthy.

#### Step D: Add PX4 + Gazebo simulation
- Launch PX4 SITL with a rover model in Gazebo.
- Make sure simulation publishes LiDAR + IMU (and camera only if you want full LIVO mode).

#### Step E: Map simulator topics to FAST-LIVO2 config
Edit a config YAML (copy from `config/NTU_VIRAL.yaml` is a good non-Livox starting point):
- `common.lid_topic`: set to your Gazebo LiDAR topic
- `common.imu_topic`: set to your IMU topic
- `common.img_en`: `0` if no camera
- `imu.imu_en`: `true`
- `preprocess.lidar_type`: match your LiDAR message format

Useful references:
- Topic fields in config: [NTU_VIRAL.yaml](/home/liu99/projects/fast-livo2/config/NTU_VIRAL.yaml:1)
- LiDAR type enum: [common_lib.h](/home/liu99/projects/fast-livo2/include/common_lib.h:38)
- Non-Livox point cloud parser (expects ring/time style fields): [preprocess.cpp](/home/liu99/projects/fast-livo2/src/preprocess.cpp:346)

#### Step F: Run and verify in RViz
Success looks like:
- `/cloud_registered` grows as rover moves.
- `/path` updates.
- RViz shows map shape that matches world.

---

### 2. Do I need physical machines/sensors?
**No.**
You can do this fully virtual on one laptop:
- PX4 SITL (virtual autopilot)
- Gazebo (virtual world + virtual sensors)
- FAST-LIVO2 (mapping node)
- RViz (viewer)

Physical hardware is optional, not required for this task.

---

### 3. Is this difficult?
Short answer: **medium-to-hard for a beginner**.

Difficulty is not the math first. The hard part is system integration:
- ROS version mismatch (ROS1 vs ROS2)
- simulator topic formats
- timestamp sync between LiDAR/IMU/image
- configuration tuning

A realistic difficulty score for a new person:
- 7/10 if you start directly with PX4+Gazebo+FAST-LIVO2
- 4/10 if you first run FAST-LIVO2 on provided rosbag, then integrate simulation

## 4) Recommended Beginner Strategy (To Actually Finish)
1. Build FAST-LIVO2 in Ubuntu 20.04 ROS1 VM.
2. Run provided bag example until RViz map works.
3. Start PX4 Gazebo rover with LiDAR+IMU.
4. Switch FAST-LIVO2 to `ONLY_LIO` first (`img_en: 0`, `imu_en: true`).
5. Get stable map from LiDAR+IMU.
6. Only then add camera and full LIVO mode (optional).

This reduces chaos and makes debugging possible.

## 5) External Notes (Current Ecosystem)
As of 2026-04-13:
- ROS Noetic timeline and target platform are documented in REP-0003 (Noetic: May 2020 to May 2025, Ubuntu 20.04 target).
- Gazebo Classic site states Classic reached end-of-life in January 2025.
- PX4 docs mark ROS1 as deprecated and focus on ROS2 + Gazebo (new Gazebo line).
- ROS1 bridge docs state Ubuntu 24.04 is not compatible with ROS1 bridge workflows.

These are exactly why a ROS1-compatible environment (VM/container) is the practical path for this specific repository.

## 6) Practical Conclusion For You
You can complete this task with only your laptop.

But because this repo is ROS1-era software, the safest path is:
- run a ROS1 Ubuntu 20.04 environment,
- validate FAST-LIVO2 first on bag,
- then connect PX4+Gazebo rover sensors,
- and verify `/cloud_registered` in RViz.

That is the shortest path to success with the least frustration.

## 7) Useful Links
- FAST-LIVO2 repo: https://github.com/hku-mars/FAST-LIVO2
- REP-0003 (ROS target platforms): https://reps.openrobotics.org/rep-0003/
- Gazebo Classic page: https://classic.gazebosim.org/
- PX4 Gazebo (new Gazebo) guide: https://docs.px4.io/main/en/sim_gazebo_gz/
- PX4 Gazebo Classic guide: https://docs.px4.io/main/en/sim_gazebo_classic/
- ros1_bridge compatibility: https://docs.ros.org/en/humble/p/ros1_bridge/
