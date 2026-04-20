#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/workspace/context/test-task-130426/plan/communication/agent"
NOW="$(date +%Y%m%d-%H%M%S)"
EVIDENCE_DIR="${ROOT_DIR}/submission-check-${NOW}"
mkdir -p "${EVIDENCE_DIR}"

RUNTIME_ENV="/workspace/.submission_runtime/env.sh"
if [ -f "${RUNTIME_ENV}" ]; then
  # shellcheck disable=SC1090
  source "${RUNTIME_ENV}"
else
  export ROS_MASTER_URI="http://127.0.0.1:12711"
  export GAZEBO_MASTER_URI="http://127.0.0.1:12745"
fi

set +u
source /opt/ros/noetic/setup.bash
source /workspace/catkin_ws/devel/setup.bash
set -u

rate_of() {
  local topic="$1"
  timeout 8 rostopic hz "${topic}" 2>/dev/null | awk '/average rate:/ {print $3; exit}' || true
}

is_positive() {
  local v="${1:-0}"
  awk -v x="${v}" 'BEGIN{ if (x+0 > 0) exit 0; exit 1 }'
}

extract_int_field() {
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

status_line() {
  local name="$1"
  local value="$2"
  local pass="$3"
  printf "%-22s %-8s %s\n" "${name}" "${pass}" "${value}"
}

PASS_COUNT=0
FAIL_COUNT=0

LASER_RATE="$(rate_of /laser/scan)"
if is_positive "${LASER_RATE}"; then
  LASER_PASS="PASS"; PASS_COUNT=$((PASS_COUNT + 1))
else
  LASER_PASS="FAIL"; FAIL_COUNT=$((FAIL_COUNT + 1))
fi

IMU_TOPIC="/livox/imu"
IMU_RATE="$(rate_of /livox/imu)"
if ! is_positive "${IMU_RATE}"; then
  IMU_TOPIC="/imu"
  IMU_RATE="$(rate_of /imu)"
fi
if is_positive "${IMU_RATE}"; then
  IMU_PASS="PASS"; PASS_COUNT=$((PASS_COUNT + 1))
else
  IMU_PASS="FAIL"; FAIL_COUNT=$((FAIL_COUNT + 1))
fi

timeout 6 rostopic echo -n 1 /points_raw >"${EVIDENCE_DIR}/points_raw_echo.log" 2>&1 || true
POINTS_WIDTH="$(extract_int_field "width:" "${EVIDENCE_DIR}/points_raw_echo.log")"
[ -n "${POINTS_WIDTH}" ] || POINTS_WIDTH="0"
if is_positive "${POINTS_WIDTH}"; then
  POINTS_PASS="PASS"; PASS_COUNT=$((PASS_COUNT + 1))
else
  POINTS_PASS="FAIL"; FAIL_COUNT=$((FAIL_COUNT + 1))
fi

timeout 6 rostopic echo -n 1 /livox/lidar >"${EVIDENCE_DIR}/livox_lidar_echo.log" 2>&1 || true
LIVOX_POINT_NUM="$(extract_int_field "point_num:" "${EVIDENCE_DIR}/livox_lidar_echo.log")"
[ -n "${LIVOX_POINT_NUM}" ] || LIVOX_POINT_NUM="0"
if is_positive "${LIVOX_POINT_NUM}"; then
  LIVOX_PASS="PASS"; PASS_COUNT=$((PASS_COUNT + 1))
else
  LIVOX_PASS="FAIL"; FAIL_COUNT=$((FAIL_COUNT + 1))
fi

CLOUD_RATE="$(rate_of /cloud_registered)"
timeout 6 rostopic echo -n 1 /cloud_registered >"${EVIDENCE_DIR}/cloud_registered_echo.log" 2>&1 || true
CLOUD_WIDTH="$(extract_int_field "width:" "${EVIDENCE_DIR}/cloud_registered_echo.log")"
[ -n "${CLOUD_WIDTH}" ] || CLOUD_WIDTH="0"
if is_positive "${CLOUD_RATE}" && is_positive "${CLOUD_WIDTH}"; then
  CLOUD_PASS="PASS"; PASS_COUNT=$((PASS_COUNT + 1))
else
  CLOUD_PASS="FAIL"; FAIL_COUNT=$((FAIL_COUNT + 1))
fi

{
  echo "Submission Check (${NOW})"
  echo "ROS_MASTER_URI=${ROS_MASTER_URI}"
  echo "GAZEBO_MASTER_URI=${GAZEBO_MASTER_URI}"
  echo
  echo "Topic Check Table"
  status_line "/laser/scan rate>0" "${LASER_RATE}" "${LASER_PASS}"
  status_line "${IMU_TOPIC} rate>0" "${IMU_RATE}" "${IMU_PASS}"
  status_line "/points_raw width>0" "${POINTS_WIDTH}" "${POINTS_PASS}"
  status_line "/livox/lidar point_num>0" "${LIVOX_POINT_NUM}" "${LIVOX_PASS}"
  status_line "/cloud_registered width>0 + rate>0" "width=${CLOUD_WIDTH} rate=${CLOUD_RATE}" "${CLOUD_PASS}"
  echo
  echo "PASS_COUNT=${PASS_COUNT}"
  echo "FAIL_COUNT=${FAIL_COUNT}"
} | tee "${EVIDENCE_DIR}/check-summary.txt"

if [ "${FAIL_COUNT}" -gt 0 ]; then
  exit 1
fi
