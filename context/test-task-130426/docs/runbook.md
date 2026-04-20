# FAST-LIVO2 Runbook (Laptop-Only)

## Scope
This runbook gives you an end-to-end path to complete the task:
- run FAST-LIVO2,
- connect it to simulated robot sensors,
- see a 3D point cloud in RViz,
- no physical robot required.

Target setup in this runbook:
- Host: your current laptop (Pop!_OS 24.04)
- Guest: Ubuntu 20.04 VM (recommended for ROS1 Noetic + FAST-LIVO2)

## Success Criteria
You are done when all are true:
1. `roslaunch fast_livo ...` starts without crashes.
2. `rostopic hz /cloud_registered` shows regular output.
3. RViz shows a growing map while simulated rover moves.
4. `rostopic echo /path` shows pose updates.

## Phase 0: Prepare VM
1. Create Ubuntu 20.04 VM.
2. Give it enough resources:
- CPU: 4+ cores
- RAM: 8-16 GB
- Disk: 60+ GB
- 3D acceleration: enabled (if available)
3. In VM, update system:

```bash
sudo apt update && sudo apt upgrade -y
```

## Phase 1: Install ROS1 + FAST-LIVO2 Dependencies

```bash
sudo apt update
sudo apt install -y \
  curl gnupg2 lsb-release ca-certificates \
  build-essential cmake git python3-catkin-tools

# ROS1 Noetic repo
sudo sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros1-latest.list'
curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | sudo apt-key add -
sudo apt update

# ROS + common libs
sudo apt install -y \
  ros-noetic-desktop-full \
  ros-noetic-pcl-ros \
  ros-noetic-cv-bridge \
  ros-noetic-image-transport \
  ros-noetic-tf \
  ros-noetic-eigen-conversions \
  ros-noetic-rviz \
  libpcl-dev libeigen3-dev libopencv-dev

# ROS environment
echo "source /opt/ros/noetic/setup.bash" >> ~/.bashrc
source ~/.bashrc
```

Install Sophus (required by repo):

```bash
git clone https://github.com/strasdat/Sophus.git
cd Sophus
git checkout a621ff
mkdir -p build && cd build
cmake ..
make -j$(nproc)
sudo make install
```

## Phase 2: Build FAST-LIVO2 Workspace

```bash
source /opt/ros/noetic/setup.bash
mkdir -p ~/catkin_ws/src
cd ~/catkin_ws/src

# dependencies + project
git clone https://github.com/xuankuzcr/rpg_vikit.git
git clone https://github.com/hku-mars/FAST-LIVO2.git fast-livo2

cd ~/catkin_ws
catkin_make
source devel/setup.bash
```

If build fails, run:

```bash
catkin_make --cmake-args -DCMAKE_BUILD_TYPE=Release
```

## Phase 3: Baseline Test (Before PX4)
Use the repo’s bag-based flow first.

Terminal A:
```bash
source /opt/ros/noetic/setup.bash
source ~/catkin_ws/devel/setup.bash
roslaunch fast_livo mapping_avia.launch
```

Terminal B:
```bash
source /opt/ros/noetic/setup.bash
source ~/catkin_ws/devel/setup.bash
rosbag play /path/to/your.bag --clock
```

Terminal C (checks):
```bash
source /opt/ros/noetic/setup.bash
source ~/catkin_ws/devel/setup.bash
rostopic list | rg "cloud_registered|path|aft_mapped_to_init"
rostopic hz /cloud_registered
rostopic hz /path
```

If this phase works, FAST-LIVO2 itself is healthy.

## Phase 4: PX4 + Gazebo Integration (Simulation)
Goal: replace bag inputs with simulator topics.

### 4.1 Start PX4 SITL + Gazebo rover
Use your PX4 workflow for Gazebo rover simulation (inside same VM).

### 4.2 Discover simulator topics

```bash
rostopic list
rostopic type /your/lidar/topic
rostopic type /your/imu/topic
rostopic type /your/camera/topic   # optional
```

### 4.3 Create a simulation config for FAST-LIVO2
Copy a non-Livox template:

```bash
cp ~/catkin_ws/src/fast-livo2/config/NTU_VIRAL.yaml \
   ~/catkin_ws/src/fast-livo2/config/sim_rover.yaml
```

Edit `sim_rover.yaml`:
- `common.lid_topic`: your simulator LiDAR topic
- `common.imu_topic`: your simulator IMU topic
- `common.img_topic`: camera topic (if using camera)
- `common.img_en`: `0` for LiDAR+IMU only, `1` for full LIVO
- `imu.imu_en`: `true`
- `preprocess.lidar_type`: set correctly

LiDAR type mapping:
- `1` AVIA (Livox CustomMsg)
- `2` VELO16 (Velodyne-style PointCloud2)
- `3` OUST64 (Ouster-style PointCloud2)
- `5` XT32 (Hesai XT32)
- `6` Pandar128
- `7` RoboSense

### 4.4 Create launch file for your sim config
Create `~/catkin_ws/src/fast-livo2/launch/mapping_sim_rover.launch`:

```xml
<launch>
  <arg name="rviz" default="true" />
  <rosparam command="load" file="$(find fast_livo)/config/sim_rover.yaml" />

  <node pkg="fast_livo" type="fastlivo_mapping" name="laserMapping" output="screen">
    <rosparam file="$(find fast_livo)/config/camera_NTU_VIRAL.yaml" />
  </node>

  <group if="$(arg rviz)">
    <node pkg="rviz" type="rviz" name="rviz" args="-d $(find fast_livo)/rviz_cfg/ntu_viral.rviz" />
  </group>
</launch>
```

Rebuild:

```bash
cd ~/catkin_ws
catkin_make
source devel/setup.bash
```

### 4.5 Run integration
Terminal A: PX4 + Gazebo

Terminal B:
```bash
source /opt/ros/noetic/setup.bash
source ~/catkin_ws/devel/setup.bash
roslaunch fast_livo mapping_sim_rover.launch
```

Terminal C (validate):
```bash
source /opt/ros/noetic/setup.bash
source ~/catkin_ws/devel/setup.bash
rostopic hz /cloud_registered
rostopic hz /aft_mapped_to_init
rostopic hz /path
```

## Phase 5: LIO-Only First, Then Full LIVO
Start simple:
1. `img_en: 0`, `imu_en: true` (LIO only)
2. verify stable map
3. then enable image (`img_en: 1`) and tune camera/extrinsics

This reduces debug complexity a lot.

## Quick Troubleshooting

### No map in RViz
- Check topic exists: `rostopic list | rg cloud_registered`
- Check frequency: `rostopic hz /cloud_registered`
- In RViz, set Fixed Frame to `camera_init`

### FAST-LIVO2 starts but no sensor data
- Topic name mismatch in YAML (`common.*_topic`)
- Wrong message type for chosen `lidar_type`

### Warnings about sync / dropped frames
- Verify timestamps are moving forward:

```bash
rostopic echo -n 1 /your/lidar/topic/header
rostopic echo -n 1 /your/imu/topic/header
```

- Tune time offsets in YAML:
- `time_offset.imu_time_offset`
- `time_offset.img_time_offset`
- `time_offset.lidar_time_offset`

### CPU too slow
- Reduce load:
- set `publish.dense_map_en: false`
- increase `preprocess.point_filter_num`
- run Gazebo headless if needed

## Deliverables Checklist
- [ ] Screenshot/video of RViz point cloud map
- [ ] Config file used (`sim_rover.yaml`)
- [ ] Launch file used (`mapping_sim_rover.launch`)
- [ ] Short note: which simulator topics were mapped to FAST-LIVO2
