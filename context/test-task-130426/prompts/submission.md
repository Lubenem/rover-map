##
[submission](~/projects/rover-map/context/test-task-130426/submission)
 - here are a guide to submition from the advisor agent
 - please guide me through it step by step like a 5-ear old. 
 - Let's create our submission data and send it to the client by the end of our work. 
 - Let's start with creating a separate tmux session for running our processes `run-ros`. 
 - then you could guide me through opening each window and running necessary commands and you will tell me
what should I take a screenshot of, and what should I video record... let's start

####
  In run-ros, create windows:

  # stack
  ~ (start container + full stack)

  cd ~/projects/rover-map
  make docker-up
  make docker-shell
  source /opt/ros/noetic/setup.bash
  source /workspace/catkin_ws/devel/setup.bash
  /workspace/tools/submission_run.sh stop || true
  /workspace/tools/submission_run.sh

  # drive
  ~ (prepare for motion command)

  cd ~/projects/rover-map
  make docker-shell
  source /workspace/.submission_runtime/env.sh
  source /opt/ros/noetic/setup.bash
  source /workspace/catkin_ws/devel/setup.bash

  # check
  ~ (prepare for PASS/FAIL check)

  cd ~/projects/rover-map
  make docker-shell
  source /workspace/.submission_runtime/env.sh
  source /opt/ros/noetic/setup.bash
  source /workspace/catkin_ws/devel/setup.bash

  After this, send me the last lines from the stack window (it should print Submission stack started + selected world). Then I’ll give you the exact
  recording sequence and what to capture first.

##

dev@tuf:/workspace$ /workspace/tools/submission_run.sh
GAZEBO_PLUGIN_PATH :/usr/lib/x86_64-linux-gnu/gazebo-11/plugins:/workspace/lib/PX4-Autopilot/build/px4_sitl_default/build_gazebo
GAZEBO_MODEL_PATH :/usr/share/gazebo-11/models:/workspace/lib/PX4-Autopilot/Tools/sitl_gazebo/models
LD_LIBRARY_PATH /opt/ros/noetic/lib:/usr/lib/x86_64-linux-gnu/gazebo-11/plugins:/workspace/lib/PX4-Autopilot/build/px4_sitl_default/build_gazebo
Submission stack started.
World: /workspace/lib/PX4-Autopilot/Tools/sitl_gazebo/worlds/warehouse.world
Model: /workspace/lib/PX4-Autopilot/Tools/sitl_gazebo/models/rover/rover_no_velodyne_rplidar_imu.sdf
Runtime env: /workspace/.submission_runtime/env.sh
Logs: /workspace/.submission_runtime/logs
Next: python3 /workspace/tools/submission_drive.py
Check: /workspace/tools/submission_check.sh
dev@tuf:/workspace$

####
• Excellent, stack is up on warehouse.world.

  # Next tiny step (do only this now)

  In your OS, start screen recording.

  Then show these three things on video (without stopping recording yet):

  1. stack window with the exact output you just pasted (Submission stack
     started...).
  2. Gazebo window (rover visible in warehouse).
  3. RViz window (open and running).

  After you’ve done this, reply done, and I’ll give you the next tiny step
  (rover motion + exact screenshot moment).

##
› done

####
• Great.

  # Next tiny step: start rover motion

  Go to drive window and run:

  python3 /workspace/tools/submission_drive.py --duration 90

  While it runs:

  1. Keep recording.
  2. Show Gazebo rover moving.
  3. Show RViz map growing.

  When motion finishes, reply done.

##
› done

####
• Perfect.

  ### Next tiny step: run final PASS check

  Go to check window and run:

  /workspace/tools/submission_check.sh

  Then on video:

  1. Keep the full PASS table visible for 3-5 seconds.
  2. Run this to show exact evidence folder path:

  ls -1dt /workspace/context/test-task-130426/plan/communication/agent/
  submission-check-* | head -n 1

  After that, tell me done and paste both outputs.

##
› dev@tuf:/workspace$  /workspace/tools/submission_check.sh
  Submission Check (20260420-051648)
  ROS_MASTER_URI=http://127.0.0.1:12711
  GAZEBO_MASTER_URI=http://127.0.0.1:12745

  Topic Check Table
  /laser/scan rate>0     PASS     9.957
  /livox/imu rate>0      PASS     103.995
  /points_raw width>0    PASS     268
  /livox/lidar point_num>0 PASS     268
  /cloud_registered width>0 + rate>0 PASS     width=268 rate=10.048

  PASS_COUNT=5
  FAIL_COUNT=0
  dev@tuf:/workspace$ ls -1dt /workspace/context/test-task-130426/plan/
  communication/agent/submission-check-* | head -n 1
  /workspace/context/test-task-130426/plan/communication/agent/submission-
  check-20260420-051648
  dev@tuf:/workspace$

####
  1. Stop the stack in your stack window:

  /workspace/tools/submission_run.sh stop

  2. Open this file and paste your video path/link:

  - projects/rover-map/context/test-task-130426/submission/final-submission-
    message.md

  Replace:

  - Demo video: <add path or link>

  You can leave screenshot fields empty or mark as not provided (video-
  only).

  Reply done and I’ll give you a final ready-to-send submission text block.
