# Step 2 - Baseline Validation (Explain Like I am 5)

## What is Step 2?
Step 2 is a **safety check**.

Before we connect everything (PX4 + Gazebo + simulator topics), we first test:
- can FAST-LIVO2 run,
- can it read sensor data,
- can it output a 3D map.

We do this with a ready-made rosbag (recorded sensor data), because it is simpler and more stable than full simulation.

---

## Like I am 5
Imagine you built a toy factory machine.

Before connecting it to a real moving conveyor belt, you test it with a small box of known test pieces.
If it fails even on test pieces, connecting the big system is pointless.

In our case:
- FAST-LIVO2 = the machine
- rosbag = the test pieces
- RViz map = proof the machine works

So Step 2 means: **"prove the core mapper works first."**

---

## Why we do Step 2 (very important)
Without Step 2, if something breaks later you won't know where the problem is.

Possible failure sources later:
- simulator topic names
- time sync issues
- LiDAR message format mismatch
- camera/IMU rates
- launch config mistakes

Step 2 removes many unknowns by proving:
- your container is fine,
- dependencies are fine,
- FAST-LIVO2 binary is fine,
- output topics appear correctly.

---

## Why we use multiple terminals
ROS tools are separate programs that must run at the same time.

- Terminal A: run FAST-LIVO2 (waits for incoming data)
- Terminal B: play rosbag (sends data)
- Terminal C (optional): monitor topics/rates

If you run only one terminal, starting command B usually stops command A, so pipeline breaks.

---

## Step 2 Goals
1. Start FAST-LIVO2 successfully.
2. Feed rosbag data.
3. Confirm map topic is publishing.
4. Confirm path/odometry topics are publishing.
5. (Optional) View map in RViz.

---

## Exact flow inside your current setup
You already have the container and build done.

### Terminal A (mapper)
```bash
cd ~/projects/rover-map
make docker-shell
source /opt/ros/noetic/setup.bash
source /workspace/catkin_ws/devel/setup.bash
roslaunch fast_livo mapping_avia.launch rviz:=false
```

What this does:
- starts the FAST-LIVO2 node
- loads `config/avia.yaml`
- waits for LiDAR/IMU/image topics

### Terminal B (data source)
```bash
cd ~/projects/rover-map
make docker-shell
source /opt/ros/noetic/setup.bash
source /workspace/catkin_ws/devel/setup.bash
rosbag play /ABSOLUTE/PATH/TO/YOUR.bag --clock
```

What this does:
- publishes recorded sensor messages into ROS topics
- acts like a fake robot run

### Terminal C (monitor, optional but recommended)
```bash
cd ~/projects/rover-map
make docker-shell
source /opt/ros/noetic/setup.bash
source /workspace/catkin_ws/devel/setup.bash
rostopic hz /cloud_registered
rostopic hz /path
rostopic hz /aft_mapped_to_init
```

What this does:
- confirms FAST-LIVO2 is producing outputs continuously

---

## What success looks like
You can call Step 2 successful when:
- launch starts without crash,
- rosbag plays without fatal topic/type errors,
- `/cloud_registered` has non-zero publish rate,
- `/path` updates over time,
- (if RViz enabled) map grows visually.

---

## Common confusion points (simple answers)

### "Why source every terminal?"
Each terminal is a new shell. It forgets ROS paths until you `source` again.

### "Why run with rosbag if final task is simulation?"
Because rosbag is controlled input. It proves mapper works before adding simulator complexity.

### "Do we need RViz in Step 2?"
Not strictly. Topic rates are enough for functional proof. RViz is visual confirmation.

---

## Failure checklist (if Step 2 fails)
1. `fast_livo` package missing:
- run `source /workspace/catkin_ws/devel/setup.bash`
- check `rospack find fast_livo`

2. No output topics:
- ensure rosbag is actually publishing (`rostopic list`, `rostopic hz` on input topics)
- check topic names match expected config

3. Launch exits immediately:
- inspect logs in terminal A
- verify `make bootstrap` completed with no errors

4. Very slow/no map growth:
- bag may not contain matching LiDAR/IMU/camera topics for `avia.yaml`
- use a bag known to match repo examples first

---

## Step 2 Deliverables
Capture these as proof:
1. command history used (or short note)
2. output of `rostopic hz /cloud_registered`
3. optional screenshot of RViz map
4. note whether bag matched `mapping_avia.launch`

---

## What comes after Step 2
After this passes, move to Step 3:
- connect PX4 + Gazebo topics,
- create `sim_rover.yaml`,
- start with LIO-only (`img_en: 0`) first,
- then enable full LIVO if needed.
