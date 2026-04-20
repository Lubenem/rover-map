#!/usr/bin/env bash
set -euo pipefail

NOW="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="${1:-/workspace/context/test-task-130426/plan/communication/agent/advice6-chain-${NOW}}"
MODEL_FILE="/workspace/lib/PX4-Autopilot/Tools/sitl_gazebo/models/rover/rover_no_velodyne_rplidar_imu.sdf"
WORLD_FILE="/workspace/lib/PX4-Autopilot/Tools/sitl_gazebo/worlds/empty.world"
OBSTACLE_FILE="/workspace/tools/test_models/wall_obstacle.sdf"
MAPPER_BLIND_OVERRIDE="0.1"

mkdir -p "${OUT_DIR}"

export ROS_MASTER_URI="${ROS_MASTER_URI:-http://127.0.0.1:12611}"
export GAZEBO_MASTER_URI="${GAZEBO_MASTER_URI:-http://127.0.0.1:12645}"
export GAZEBO_MODEL_DATABASE_URI=""

set +u
source /opt/ros/noetic/setup.bash
source /workspace/lib/PX4-Autopilot/Tools/setup_gazebo.bash \
  /workspace/lib/PX4-Autopilot \
  /workspace/lib/PX4-Autopilot/build/px4_sitl_default
source /workspace/catkin_ws/devel/setup.bash
set -u

cleanup_all() {
  killall -q roslaunch rosmaster rosout gzserver gzclient gazebo px4 2>/dev/null || true
}

wait_for_service() {
  local svc="$1"
  local tries="${2:-40}"
  local i=0
  while [ "${i}" -lt "${tries}" ]; do
    if timeout 2 rosservice call "${svc}" >/dev/null 2>&1; then
      return 0
    fi
    i=$((i + 1))
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
  timeout 8 rostopic hz "${topic}" 2>/dev/null | awk '/average rate:/ {print $3; exit}' || true
}

is_positive() {
  local v="${1:-0}"
  awk -v x="${v}" 'BEGIN{ if (x+0 > 0) exit 0; exit 1 }'
}

extract_first_int() {
  local key="$1"
  local file="$2"
  [ -f "${file}" ] || return 0
  awk -v k="${key}" '
    $1 == k {
      gsub(/[^0-9]/, "", $2);
      if ($2 != "") { print $2; exit }
    }
  ' "${file}" || true
}

status_from_topic_rate_echo() {
  local topic="$1"
  local echo_file="$2"
  local rate="$3"
  local status="fail"
  : >"${echo_file}"
  if wait_for_topic "${topic}" 20; then
    if is_positive "${rate}" && timeout 6 rostopic echo -n 1 "${topic}" >"${echo_file}" 2>&1; then
      status="pass"
    fi
  fi
  echo "${status}"
}

cleanup_all
sleep 2

roslaunch gazebo_ros empty_world.launch \
  world_name:="${WORLD_FILE}" \
  gui:=false pause:=false use_sim_time:=false \
  >"${OUT_DIR}/core.log" 2>&1 &
CORE_PID=$!

if ! wait_for_service /gazebo/get_world_properties 45; then
  echo "Gazebo service did not come up" >"${OUT_DIR}/error.txt"
  exit 1
fi

rosrun gazebo_ros spawn_model -sdf -file "${MODEL_FILE}" -model rover \
  >"${OUT_DIR}/spawn.log" 2>&1

# Provide geometry in front of rover so scan points survive FAST-LIVO2 blind filtering.
if [ -f "${OBSTACLE_FILE}" ]; then
  rosrun gazebo_ros spawn_model -sdf -file "${OBSTACLE_FILE}" -model wall_obstacle \
    -x 4.0 -y 0.0 -z 1.0 >"${OUT_DIR}/obstacle_spawn.log" 2>&1 || true
fi

# Step 1: rover raw topics
LASER_RATE="$(topic_rate /laser/scan)"
IMU_RATE="$(topic_rate /imu)"
LASER_STATUS="$(status_from_topic_rate_echo /laser/scan "${OUT_DIR}/laser_scan_echo.log" "${LASER_RATE}")"
IMU_STATUS="$(status_from_topic_rate_echo /imu "${OUT_DIR}/imu_echo.log" "${IMU_RATE}")"

# Step 2: /laser/scan -> /points_raw
python3 /workspace/tools/scan_to_cloud.py >"${OUT_DIR}/scan_to_cloud.log" 2>&1 &
SCAN2CLOUD_PID=$!
sleep 2
POINTS_RAW_TYPE="$(rostopic type /points_raw 2>/dev/null || true)"
POINTS_RAW_RATE="$(topic_rate /points_raw)"
POINTS_RAW_STATUS="$(status_from_topic_rate_echo /points_raw "${OUT_DIR}/points_raw_echo.log" "${POINTS_RAW_RATE}")"
POINTS_RAW_WIDTH="$(extract_first_int "width:" "${OUT_DIR}/points_raw_echo.log")"
if [ -z "${POINTS_RAW_WIDTH}" ]; then POINTS_RAW_WIDTH="0"; fi
if ! is_positive "${POINTS_RAW_WIDTH}"; then POINTS_RAW_STATUS="fail"; fi

# Step 3: /points_raw -> /livox/lidar
python3 /workspace/tools/points_to_livox.py >"${OUT_DIR}/points_to_livox.log" 2>&1 &
P2L_PID=$!
sleep 2
LIVOX_TYPE="$(rostopic type /livox/lidar 2>/dev/null || true)"
LIVOX_RATE="$(topic_rate /livox/lidar)"
LIVOX_STATUS="$(status_from_topic_rate_echo /livox/lidar "${OUT_DIR}/livox_lidar_echo.log" "${LIVOX_RATE}")"
LIVOX_POINT_NUM="$(extract_first_int "point_num:" "${OUT_DIR}/livox_lidar_echo.log")"
if [ -z "${LIVOX_POINT_NUM}" ]; then LIVOX_POINT_NUM="0"; fi
if ! is_positive "${LIVOX_POINT_NUM}"; then LIVOX_STATUS="fail"; fi

# Step 4: IMU naming compatibility (minimal-change path)
rosrun topic_tools relay /imu /livox/imu >"${OUT_DIR}/imu_relay.log" 2>&1 &
IMU_RELAY_PID=$!
sleep 1
LIVOX_IMU_RATE="$(topic_rate /livox/imu)"
LIVOX_IMU_STATUS="$(status_from_topic_rate_echo /livox/imu "${OUT_DIR}/livox_imu_echo.log" "${LIVOX_IMU_RATE}")"

# Step 5: FAST-LIVO2 with real topics
# Keep proven AVIA path, but lower blind filter at runtime so near rover scan points are not discarded.
rosparam load /workspace/lib/fast-livo2/config/avia.yaml
rosparam set /preprocess/blind "${MAPPER_BLIND_OVERRIDE}"
rosparam load /workspace/lib/fast-livo2/config/camera_pinhole.yaml /laserMapping
rosrun fast_livo fastlivo_mapping >"${OUT_DIR}/fast_livo.log" 2>&1 &
FASTLIVO_PID=$!
sleep 20
CLOUD_RATE="$(topic_rate /cloud_registered)"
CLOUD_STATUS="$(status_from_topic_rate_echo /cloud_registered "${OUT_DIR}/cloud_registered_echo.log" "${CLOUD_RATE}")"
CLOUD_WIDTH="$(extract_first_int "width:" "${OUT_DIR}/cloud_registered_echo.log")"
if [ -z "${CLOUD_WIDTH}" ]; then CLOUD_WIDTH="0"; fi
if ! is_positive "${CLOUD_WIDTH}"; then CLOUD_STATUS="fail"; fi

FINAL_VERDICT="fail"
if [ "${LASER_STATUS}" = "pass" ] && \
   [ "${IMU_STATUS}" = "pass" ] && \
   [ "${POINTS_RAW_STATUS}" = "pass" ] && \
   [ "${LIVOX_STATUS}" = "pass" ] && \
   [ "${LIVOX_IMU_STATUS}" = "pass" ] && \
   [ "${CLOUD_STATUS}" = "pass" ]; then
  FINAL_VERDICT="pass"
fi

cat >"${OUT_DIR}/summary.txt" <<EOF
rover_model_used=${MODEL_FILE}
/laser/scan=${LASER_STATUS} rate=${LASER_RATE}
/imu=${IMU_STATUS} rate=${IMU_RATE}
/points_raw=${POINTS_RAW_STATUS} rate=${POINTS_RAW_RATE} type=${POINTS_RAW_TYPE} width=${POINTS_RAW_WIDTH}
/livox/lidar=${LIVOX_STATUS} rate=${LIVOX_RATE} type=${LIVOX_TYPE} point_num=${LIVOX_POINT_NUM}
mapper_input_topics_used=lidar:/livox/lidar imu:/livox/imu
/mapper_preprocess_blind_override=${MAPPER_BLIND_OVERRIDE}
/cloud_registered=${CLOUD_STATUS} rate=${CLOUD_RATE} width=${CLOUD_WIDTH}
final_verdict_full_real_step3=${FINAL_VERDICT}
EOF

cp "${OUT_DIR}/core.log" "${OUT_DIR}/core.measurement.log"

kill "${FASTLIVO_PID}" 2>/dev/null || true
kill "${IMU_RELAY_PID}" 2>/dev/null || true
kill "${P2L_PID}" 2>/dev/null || true
kill "${SCAN2CLOUD_PID}" 2>/dev/null || true
kill "${CORE_PID}" 2>/dev/null || true
wait "${FASTLIVO_PID}" 2>/dev/null || true
wait "${IMU_RELAY_PID}" 2>/dev/null || true
wait "${P2L_PID}" 2>/dev/null || true
wait "${SCAN2CLOUD_PID}" 2>/dev/null || true
wait "${CORE_PID}" 2>/dev/null || true
cleanup_all
cp "${OUT_DIR}/core.measurement.log" "${OUT_DIR}/core.log"

echo "${OUT_DIR}" >"${OUT_DIR}/_root_path.txt"
echo "Done. Summary at ${OUT_DIR}/summary.txt"
