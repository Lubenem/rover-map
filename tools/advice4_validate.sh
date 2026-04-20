#!/usr/bin/env bash
set -euo pipefail

NOW="$(date +%Y%m%d-%H%M%S)"
LOG_ROOT="${1:-/workspace/context/test-task-130426/plan/communication/agent/advice5-validation-${NOW}}"
WORLD_FILE="/workspace/lib/PX4-Autopilot/Tools/sitl_gazebo/worlds/empty.world"

mkdir -p "${LOG_ROOT}"

export ROS_MASTER_URI="${ROS_MASTER_URI:-http://127.0.0.1:11311}"
export GAZEBO_MASTER_URI="${GAZEBO_MASTER_URI:-http://127.0.0.1:11345}"

set +u
source /opt/ros/noetic/setup.bash
source /workspace/lib/PX4-Autopilot/Tools/setup_gazebo.bash \
  /workspace/lib/PX4-Autopilot \
  /workspace/lib/PX4-Autopilot/build/px4_sitl_default
set -u

export GAZEBO_MODEL_DATABASE_URI=""

cleanup_all() {
  killall -q roslaunch rosmaster rosout gzserver gzclient gazebo px4 2>/dev/null || true
}

wait_for_world_service() {
  local tries=0
  while [ "${tries}" -lt 40 ]; do
    if timeout 2 rosservice call /gazebo/get_world_properties >/dev/null 2>&1; then
      return 0
    fi
    tries=$((tries + 1))
    sleep 1
  done
  return 1
}

wait_for_topic() {
  local topic="$1"
  local tries="${2:-20}"
  local i=0
  while [ "${i}" -lt "${tries}" ]; do
    if rostopic list 2>/dev/null | grep -Fxq "${topic}"; then
      return 0
    fi
    i=$((i + 1))
    sleep 1
  done
  return 1
}

topic_rate() {
  local topic="$1"
  timeout 6 rostopic hz "${topic}" 2>/dev/null | awk '/average rate:/ {print $3; exit}' || true
}

topic_exists() {
  local topic="$1"
  rostopic list 2>/dev/null | grep -Fxq "${topic}"
}

is_nonzero_rate() {
  local v="${1:-}"
  awk -v x="${v}" 'BEGIN{ if (x+0 > 0) exit 0; exit 1 }'
}

gzserver_alive_for_world() {
  ps -eo stat,args | awk -v w="${WORLD_FILE}" '
    $0 ~ /gzserver/ && $0 ~ w && $1 !~ /Z/ {found=1}
    END {exit(found ? 0 : 1)}
  '
}

check_case() {
  local case_name="$1"
  local model_file="$2"
  local need_scan="$3"
  local need_imu="$4"
  local ros_port="$5"
  local gz_port="$6"

  local case_dir="${LOG_ROOT}/${case_name}"
  rm -rf "${case_dir}"
  mkdir -p "${case_dir}"

  cleanup_all
  sleep 2

  export ROS_MASTER_URI="http://127.0.0.1:${ros_port}"
  export GAZEBO_MASTER_URI="http://127.0.0.1:${gz_port}"

  : >"${case_dir}/core.log"
  : >"${case_dir}/spawn.log"

  roslaunch gazebo_ros empty_world.launch \
    world_name:="${WORLD_FILE}" \
    gui:=false pause:=false use_sim_time:=false \
    >"${case_dir}/core.log" 2>&1 &
  local core_pid=$!

  local world_up="fail"
  if wait_for_world_service; then
    world_up="pass"
  fi

  local spawn_ok="fail"
  if [ "${world_up}" = "pass" ]; then
    if rosrun gazebo_ros spawn_model -sdf -file "${model_file}" -model rover \
      >"${case_dir}/spawn.log" 2>&1; then
      spawn_ok="pass"
    fi
  fi

  local scan_status="n/a"
  local scan_rate="n/a"
  if [ "${need_scan}" = "1" ]; then
    : >"${case_dir}/scan_echo.log"
    scan_status="fail"
    scan_rate="0"
    local scan_topic_ok="no"
    local scan_rate_ok="no"
    local scan_echo_ok="no"

    wait_for_topic /laser/scan 20 || true
    if topic_exists /laser/scan; then
      scan_topic_ok="yes"
      local sr
      sr="$(topic_rate /laser/scan)"
      if [ -n "${sr}" ]; then
        scan_rate="${sr}"
      fi
      if is_nonzero_rate "${scan_rate}"; then
        scan_rate_ok="yes"
      fi
      if timeout 5 rostopic echo -n 1 /laser/scan >"${case_dir}/scan_echo.log" 2>&1; then
        scan_echo_ok="yes"
      fi
    fi
    if [ "${scan_topic_ok}" = "yes" ] && [ "${scan_rate_ok}" = "yes" ] && [ "${scan_echo_ok}" = "yes" ]; then
      scan_status="pass"
    fi
  fi

  local imu_status="n/a"
  local imu_rate="n/a"
  if [ "${need_imu}" = "1" ]; then
    : >"${case_dir}/imu_echo.log"
    imu_status="fail"
    imu_rate="0"
    local imu_topic_ok="no"
    local imu_rate_ok="no"
    local imu_echo_ok="no"

    wait_for_topic /imu 20 || true
    if topic_exists /imu; then
      imu_topic_ok="yes"
      local ir
      ir="$(topic_rate /imu)"
      if [ -n "${ir}" ]; then
        imu_rate="${ir}"
      fi
      if is_nonzero_rate "${imu_rate}"; then
        imu_rate_ok="yes"
      fi
      if timeout 5 rostopic echo -n 1 /imu >"${case_dir}/imu_echo.log" 2>&1; then
        imu_echo_ok="yes"
      fi
    fi
    if [ "${imu_topic_ok}" = "yes" ] && [ "${imu_rate_ok}" = "yes" ] && [ "${imu_echo_ok}" = "yes" ]; then
      imu_status="pass"
    fi
  fi

  sleep 30

  local clock_rate="0"
  local cr
  cr="$(topic_rate /clock)"
  if [ -n "${cr}" ]; then
    clock_rate="${cr}"
  fi
  local clock_alive="no"
  if is_nonzero_rate "${clock_rate}"; then
    clock_alive="yes"
  fi

  local service_after_30="no"
  if timeout 2 rosservice call /gazebo/get_world_properties >/dev/null 2>&1; then
    service_after_30="yes"
  fi

  local core_alive="no"
  if ps -p "${core_pid}" >/dev/null 2>&1; then
    core_alive="yes"
  fi

  local gzserver_alive="no"
  if gzserver_alive_for_world; then
    gzserver_alive="yes"
  fi

  local segfault="no"
  cp "${case_dir}/core.log" "${case_dir}/core.measurement.log"
  if grep -qi "Segmentation fault" "${case_dir}/core.measurement.log"; then
    segfault="yes"
  fi

  local stable_30="fail"
  if [ "${spawn_ok}" = "pass" ] && \
     [ "${gzserver_alive}" = "yes" ] && \
     [ "${service_after_30}" = "yes" ] && \
     [ "${clock_alive}" = "yes" ] && \
     [ "${segfault}" = "no" ]; then
    stable_30="pass"
  fi

  cat >"${case_dir}/summary.txt" <<EOF
case=${case_name}
model=${model_file}
world_up=${world_up}
spawn_ok=${spawn_ok}
clock_rate=${clock_rate}
scan_status=${scan_status}
scan_rate=${scan_rate}
imu_status=${imu_status}
imu_rate=${imu_rate}
stable_30=${stable_30}
core_alive=${core_alive}
segfault=${segfault}
EOF

  kill "${core_pid}" 2>/dev/null || true
  wait "${core_pid}" 2>/dev/null || true
  cleanup_all
  sleep 2
  cp "${case_dir}/core.measurement.log" "${case_dir}/core.log"
}

check_case \
  "01_stable_no_velodyne" \
  "/workspace/lib/PX4-Autopilot/Tools/sitl_gazebo/models/rover/rover_no_velodyne.sdf" \
  "0" "0" "12411" "12445"

check_case \
  "02_lidar_only" \
  "/workspace/lib/PX4-Autopilot/Tools/sitl_gazebo/models/rover/rover_no_velodyne_rplidar.sdf" \
  "1" "0" "12412" "12446"

check_case \
  "03_imu_only" \
  "/workspace/lib/PX4-Autopilot/Tools/sitl_gazebo/models/rover/rover_no_velodyne_imu.sdf" \
  "0" "1" "12413" "12447"

check_case \
  "04_lidar_imu" \
  "/workspace/lib/PX4-Autopilot/Tools/sitl_gazebo/models/rover/rover_no_velodyne_rplidar_imu.sdf" \
  "1" "1" "12414" "12448"

echo "${LOG_ROOT}" >"${LOG_ROOT}/_root_path.txt"
echo "Done. Summaries are in ${LOG_ROOT}"
