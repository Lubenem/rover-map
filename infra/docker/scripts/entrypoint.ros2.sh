#!/usr/bin/env bash
set -eo pipefail

export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-42}"
export GZ_VERSION="${GZ_VERSION:-harmonic}"

set +u
source /opt/ros/humble/setup.bash
if [[ -f /workspace/colcon_ws/install/setup.bash ]]; then
  source /workspace/colcon_ws/install/setup.bash
fi
set -u

exec "$@"
