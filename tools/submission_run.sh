#!/usr/bin/env bash
set -euo pipefail

CMD="start"
if [ "${1:-}" = "start" ] || [ "${1:-}" = "stop" ] || [ "${1:-}" = "status" ]; then
  CMD="$1"
  shift || true
fi

RVIZ_ENABLED=1
GAZEBO_GUI=1
FOREGROUND=0
WORLD_OVERRIDE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --rviz) RVIZ_ENABLED=1 ;;
    --no-rviz) RVIZ_ENABLED=0 ;;
    --gui) GAZEBO_GUI=1 ;;
    --headless) GAZEBO_GUI=0; RVIZ_ENABLED=0 ;;
    --foreground) FOREGROUND=1 ;;
    --world)
      shift
      WORLD_OVERRIDE="${1:-}"
      if [ -z "${WORLD_OVERRIDE}" ]; then
        echo "Missing value for --world" >&2
        exit 1
      fi
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
  shift
done

RUNTIME_DIR="/workspace/.submission_runtime"
LOG_DIR="${RUNTIME_DIR}/logs"
ENV_FILE="${RUNTIME_DIR}/env.sh"
PID_FILE="${RUNTIME_DIR}/pids.txt"
STATUS_FILE="${RUNTIME_DIR}/status.txt"

ROS_PORT="12711"
GAZEBO_PORT="12745"
MODEL_FILE="/workspace/lib/PX4-Autopilot/Tools/sitl_gazebo/models/rover/rover_no_velodyne_rplidar_imu.sdf"
BLIND_OVERRIDE="0.1"
PRIMARY_WORLD="/workspace/lib/PX4-Autopilot/Tools/sitl_gazebo/worlds/warehouse.world"
FALLBACK_WORLD="/workspace/lib/PX4-Autopilot/Tools/sitl_gazebo/worlds/yosemite.world"

source_stack() {
  export ROS_MASTER_URI="http://127.0.0.1:${ROS_PORT}"
  export GAZEBO_MASTER_URI="http://127.0.0.1:${GAZEBO_PORT}"
  export GAZEBO_MODEL_DATABASE_URI=""
  set +u
  source /opt/ros/noetic/setup.bash
  source /workspace/lib/PX4-Autopilot/Tools/setup_gazebo.bash \
    /workspace/lib/PX4-Autopilot \
    /workspace/lib/PX4-Autopilot/build/px4_sitl_default
  source /workspace/catkin_ws/devel/setup.bash
  set -u
}

wait_for_world_service() {
  local tries=0
  while [ "${tries}" -lt 180 ]; do
    if timeout 2 rosservice call /gazebo/get_world_properties >/dev/null 2>&1; then
      return 0
    fi
    tries=$((tries + 1))
    sleep 1
  done
  return 1
}

cleanup_by_pidfile() {
  if [ -f "${PID_FILE}" ]; then
    tac "${PID_FILE}" | while read -r p; do
      [ -n "${p}" ] || continue
      kill "${p}" 2>/dev/null || true
    done
    sleep 1
    tac "${PID_FILE}" | while read -r p; do
      [ -n "${p}" ] || continue
      kill -9 "${p}" 2>/dev/null || true
    done
  fi
}

write_env_file() {
  local world="$1"
  mkdir -p "${RUNTIME_DIR}"
  cat >"${ENV_FILE}" <<EOF
export ROS_MASTER_URI=http://127.0.0.1:${ROS_PORT}
export GAZEBO_MASTER_URI=http://127.0.0.1:${GAZEBO_PORT}
export SUBMISSION_WORLD=${world}
export SUBMISSION_MODEL=${MODEL_FILE}
export SUBMISSION_BLIND_OVERRIDE=${BLIND_OVERRIDE}
EOF
}

write_status_file() {
  local world="$1"
  cat >"${STATUS_FILE}" <<EOF
status=running
world=${world}
model=${MODEL_FILE}
rviz=${RVIZ_ENABLED}
gazebo_gui=${GAZEBO_GUI}
blind_override=${BLIND_OVERRIDE}
started_at=$(date --iso-8601=seconds)
EOF
}

start_stack() {
  source_stack
  mkdir -p "${LOG_DIR}"
  : > "${PID_FILE}"

  local worlds=()
  if [ -n "${WORLD_OVERRIDE}" ]; then
    worlds=("${WORLD_OVERRIDE}")
  else
    worlds=("${PRIMARY_WORLD}" "${FALLBACK_WORLD}")
  fi

  local selected_world=""
  local core_pid=""
  for w in "${worlds[@]}"; do
    if [ ! -f "${w}" ]; then
      continue
    fi
    roslaunch gazebo_ros empty_world.launch \
      world_name:="${w}" \
      gui:=$([ "${GAZEBO_GUI}" -eq 1 ] && echo true || echo false) \
      pause:=false use_sim_time:=false \
      >"${LOG_DIR}/core.log" 2>&1 &
    core_pid=$!
    if wait_for_world_service; then
      selected_world="${w}"
      break
    fi
    kill "${core_pid}" 2>/dev/null || true
    wait "${core_pid}" 2>/dev/null || true
  done

  if [ -z "${selected_world}" ]; then
    echo "Failed to start Gazebo with primary/fallback world." >&2
    exit 1
  fi

  echo "${core_pid}" >>"${PID_FILE}"

  rosrun gazebo_ros spawn_model -sdf -file "${MODEL_FILE}" -model rover \
    >"${LOG_DIR}/spawn.log" 2>&1

  python3 /workspace/tools/scan_to_cloud.py >"${LOG_DIR}/scan_to_cloud.log" 2>&1 &
  local scan_pid=$!
  echo "${scan_pid}" >>"${PID_FILE}"

  python3 /workspace/tools/points_to_livox.py >"${LOG_DIR}/points_to_livox.log" 2>&1 &
  local p2l_pid=$!
  echo "${p2l_pid}" >>"${PID_FILE}"

  rosrun topic_tools relay /imu /livox/imu >"${LOG_DIR}/imu_relay.log" 2>&1 &
  local relay_pid=$!
  echo "${relay_pid}" >>"${PID_FILE}"

  rosparam load /workspace/lib/fast-livo2/config/avia.yaml
  rosparam set /preprocess/blind "${BLIND_OVERRIDE}"
  rosparam load /workspace/lib/fast-livo2/config/camera_pinhole.yaml /laserMapping

  rosrun fast_livo fastlivo_mapping >"${LOG_DIR}/fast_livo.log" 2>&1 &
  local mapper_pid=$!
  echo "${mapper_pid}" >>"${PID_FILE}"

  if [ "${RVIZ_ENABLED}" -eq 1 ]; then
    rviz -d /workspace/lib/fast-livo2/rviz_cfg/fast_livo2.rviz >"${LOG_DIR}/rviz.log" 2>&1 &
    local rviz_pid=$!
    echo "${rviz_pid}" >>"${PID_FILE}"
  fi

  write_env_file "${selected_world}"
  write_status_file "${selected_world}"

  echo "Submission stack started."
  echo "World: ${selected_world}"
  echo "Model: ${MODEL_FILE}"
  echo "Runtime env: ${ENV_FILE}"
  echo "Logs: ${LOG_DIR}"
  echo "Next: python3 /workspace/tools/submission_drive.py"
  echo "Check: /workspace/tools/submission_check.sh"

  if [ "${FOREGROUND}" -eq 1 ]; then
    trap 'cleanup_by_pidfile' INT TERM EXIT
    wait "${core_pid}"
  fi
}

status_stack() {
  if [ -f "${STATUS_FILE}" ]; then
    cat "${STATUS_FILE}"
  else
    echo "status=stopped"
  fi
}

stop_stack() {
  cleanup_by_pidfile
  rm -f "${PID_FILE}" "${STATUS_FILE}" "${ENV_FILE}"
  echo "Submission stack stopped."
}

case "${CMD}" in
  start)
    stop_stack >/dev/null 2>&1 || true
    start_stack
    ;;
  stop)
    stop_stack
    ;;
  status)
    status_stack
    ;;
  *)
    echo "Unsupported command: ${CMD}" >&2
    exit 1
    ;;
esac
