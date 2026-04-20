#!/usr/bin/env bash
set -euo pipefail

set +u
source /opt/ros/noetic/setup.bash

if [[ -f /workspace/catkin_ws/devel/setup.bash ]]; then
  source /workspace/catkin_ws/devel/setup.bash
fi
set -u

echo "[1/3] ROS version"
rosversion -d

echo "[2/3] Check package"
rospack find fast_livo

echo "[3/3] Check key topics from launch file parse"
roslaunch --files fast_livo mapping_avia.launch >/dev/null

echo "Environment test passed."
