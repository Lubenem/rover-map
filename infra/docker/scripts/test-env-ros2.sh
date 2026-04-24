#!/usr/bin/env bash
set -euo pipefail

set +u
source /opt/ros/humble/setup.bash
if [[ -f /workspace/colcon_ws/install/setup.bash ]]; then
  source /workspace/colcon_ws/install/setup.bash
fi
set -u

echo "[1/3] ROS 2 version"
if ! command -v ros2 >/dev/null 2>&1; then
  echo "ros2 CLI not found in PATH" >&2
  exit 1
fi
ros2 --help >/tmp/ros2-help.txt
head -n 3 /tmp/ros2-help.txt

echo "[2/3] Gazebo Harmonic availability"
gz sim --versions

echo "[3/3] PX4 target listing"
PX4_DIR="${PX4_DIR:-/workspace/lib/PX4-Autopilot-ros2}"
if [[ ! -d "${PX4_DIR}" ]] && [[ -d /workspace/lib/PX4-Autopilot ]]; then
  PX4_DIR="/workspace/lib/PX4-Autopilot"
fi

if [[ ! -d "${PX4_DIR}" ]]; then
  echo "Missing PX4 repo at ${PX4_DIR}" >&2
  exit 1
fi

cd "${PX4_DIR}"
make list_config_targets >/tmp/px4-targets.txt
if ! grep -q '^px4_sitl' /tmp/px4-targets.txt; then
  echo "PX4 target list did not include px4_sitl entries" >&2
  exit 1
fi

find "${PX4_DIR}/ROMFS/px4fmu_common/init.d-posix/airframes" -maxdepth 1 -type f -printf '%f\n' \
  | sed -nE 's/^[0-9]+_(gz_[A-Za-z0-9_]+)$/\1/p' \
  | sort -u >/tmp/px4-gz-targets.txt

if ! [[ -s /tmp/px4-gz-targets.txt ]]; then
  echo "PX4 airframes did not expose any gz_* targets (needed for Gazebo Harmonic)." >&2
  exit 1
fi

echo "Sample targets:"
grep '^px4_sitl' /tmp/px4-targets.txt | head -n 10
echo "Sample Gazebo Harmonic targets:"
head -n 10 /tmp/px4-gz-targets.txt

echo "ROS2 environment test passed."
