#!/usr/bin/env bash
set -euo pipefail

# Phase G checks for ROS2 + Gazebo Harmonic + PX4 + FAST-LIVO2 pipeline.

ROOT_DIR="/workspace/artifacts/ros2"
NOW="$(date +%Y%m%d-%H%M%S)"
EVIDENCE_DIR="${ROOT_DIR}/submission-check-${NOW}"
RUNTIME_ENV="/workspace/.submission_runtime_ros2/env.sh"

mkdir -p "${EVIDENCE_DIR}"

if [ -f "${RUNTIME_ENV}" ]; then
# shellcheck disable=SC1090
  source "${RUNTIME_ENV}"
fi

set +u
source /opt/ros/humble/setup.bash
if [ -f /workspace/colcon_ws/install/setup.bash ]; then
  source /workspace/colcon_ws/install/setup.bash
fi
set -u

probe_raw() {
  local topic="$1"
  local msg_type="$2"
  local timeout_s="$3"
  local min_msgs="$4"
  local metric="${5:-none}"

  python3 /workspace/tools/ros2_topic_probe.py \
    --topic "${topic}" \
    --msg-type "${msg_type}" \
    --timeout "${timeout_s}" \
    --min-msgs "${min_msgs}" \
    --metric "${metric}" 2>&1
}

extract_value() {
  local text="$1"
  local key="$2"
  echo "${text}" | awk -v k="${key}" '{
    for (i=1; i<=NF; i++) {
      if ($i ~ ("^" k "=")) {
        split($i, arr, "=");
        print arr[2];
        exit;
      }
    }
  }'
}

is_positive() {
  local v="${1:-0}"
  awk -v x="${v}" 'BEGIN{ if (x+0 > 0) exit 0; exit 1 }'
}

status_line() {
  local name="$1"
  local value="$2"
  local pass="$3"
  printf "%-40s %-8s %s\n" "${name}" "${pass}" "${value}"
}

PASS_COUNT=0
FAIL_COUNT=0

if [ "${SUBMISSION_LIDAR_SOURCE:-unknown}" = "gazebo" ]; then
  LIDAR_SOURCE_PASS="PASS"; PASS_COUNT=$((PASS_COUNT + 1))
else
  LIDAR_SOURCE_PASS="FAIL"; FAIL_COUNT=$((FAIL_COUNT + 1))
fi

LASER_RAW="$(probe_raw /laser/scan sensor_msgs/msg/LaserScan 45 3 none || true)"
IMU_RAW="$(probe_raw /livox/imu sensor_msgs/msg/Imu 45 6 none || true)"
POINTS_RAW_METRIC="$(probe_raw /points_raw sensor_msgs/msg/PointCloud2 45 2 pointcloud_width || true)"
LIVOX_RAW_RATE="$(probe_raw /livox/lidar livox_ros_driver2/msg/CustomMsg 45 3 none || true)"
LIVOX_RAW_POINTS="$(probe_raw /livox/lidar livox_ros_driver2/msg/CustomMsg 45 1 livox_point_num || true)"
LIVOX_RAW_REFL="$(probe_raw /livox/lidar livox_ros_driver2/msg/CustomMsg 45 1 livox_reflectivity_variance || true)"
CLOUD_RAW_RATE="$(probe_raw /cloud_registered sensor_msgs/msg/PointCloud2 90 3 none || true)"
CLOUD_RAW_WIDTH="$(probe_raw /cloud_registered sensor_msgs/msg/PointCloud2 90 1 pointcloud_width || true)"

LASER_RATE="$(extract_value "${LASER_RAW}" rate)"
IMU_RATE="$(extract_value "${IMU_RAW}" rate)"
POINTS_WIDTH="$(extract_value "${POINTS_RAW_METRIC}" width_max)"
LIVOX_RATE="$(extract_value "${LIVOX_RAW_RATE}" rate)"
LIVOX_POINT_NUM="$(extract_value "${LIVOX_RAW_POINTS}" point_num_max)"
REFLECTIVITY_VARIANCE="$(extract_value "${LIVOX_RAW_REFL}" reflectivity_variance)"
CLOUD_RATE="$(extract_value "${CLOUD_RAW_RATE}" rate)"
CLOUD_WIDTH="$(extract_value "${CLOUD_RAW_WIDTH}" width_max)"

if is_positive "${LASER_RATE}"; then
  LASER_PASS="PASS"; PASS_COUNT=$((PASS_COUNT + 1))
else
  LASER_PASS="FAIL"; FAIL_COUNT=$((FAIL_COUNT + 1))
fi

if is_positive "${IMU_RATE}"; then
  IMU_PASS="PASS"; PASS_COUNT=$((PASS_COUNT + 1))
else
  IMU_PASS="FAIL"; FAIL_COUNT=$((FAIL_COUNT + 1))
fi

if is_positive "${POINTS_WIDTH}"; then
  POINTS_PASS="PASS"; PASS_COUNT=$((PASS_COUNT + 1))
else
  POINTS_PASS="FAIL"; FAIL_COUNT=$((FAIL_COUNT + 1))
fi

if is_positive "${LIVOX_POINT_NUM}"; then
  LIVOX_PASS="PASS"; PASS_COUNT=$((PASS_COUNT + 1))
else
  LIVOX_PASS="FAIL"; FAIL_COUNT=$((FAIL_COUNT + 1))
fi

if is_positive "${CLOUD_RATE}" && is_positive "${CLOUD_WIDTH}"; then
  CLOUD_PASS="PASS"; PASS_COUNT=$((PASS_COUNT + 1))
else
  CLOUD_PASS="FAIL"; FAIL_COUNT=$((FAIL_COUNT + 1))
fi

if is_positive "${REFLECTIVITY_VARIANCE}"; then
  REFL_PASS="PASS"; PASS_COUNT=$((PASS_COUNT + 1))
else
  REFL_PASS="FAIL"; FAIL_COUNT=$((FAIL_COUNT + 1))
fi

printf "%s\n" "${LASER_RAW}" >"${EVIDENCE_DIR}/laser_scan_probe.log"
printf "%s\n" "${IMU_RAW}" >"${EVIDENCE_DIR}/livox_imu_probe.log"
printf "%s\n" "${POINTS_RAW_METRIC}" >"${EVIDENCE_DIR}/points_raw_probe.log"
printf "%s\n" "${LIVOX_RAW_RATE}" >"${EVIDENCE_DIR}/livox_lidar_rate_probe.log"
printf "%s\n" "${LIVOX_RAW_POINTS}" >"${EVIDENCE_DIR}/livox_lidar_point_num_probe.log"
printf "%s\n" "${LIVOX_RAW_REFL}" >"${EVIDENCE_DIR}/livox_lidar_reflectivity_probe.log"
printf "%s\n" "${CLOUD_RAW_RATE}" >"${EVIDENCE_DIR}/cloud_registered_rate_probe.log"
printf "%s\n" "${CLOUD_RAW_WIDTH}" >"${EVIDENCE_DIR}/cloud_registered_width_probe.log"

{
  echo "Submission Check ROS2 (${NOW})"
  echo "phase=G"
  echo "world=${SUBMISSION_WORLD_NAME:-unknown}"
  echo "model=${SUBMISSION_MODEL_NAME:-unknown}"
  echo "imu_topic=${SUBMISSION_GZ_IMU_TOPIC:-unknown}"
  echo "lidar_topic=${SUBMISSION_GZ_LIDAR_TOPIC:-unknown}"
  echo "lidar_source=${SUBMISSION_LIDAR_SOURCE:-unknown}"
  echo
  echo "Topic Check Table"
  status_line "lidar_source==gazebo" "${SUBMISSION_LIDAR_SOURCE:-unknown}" "${LIDAR_SOURCE_PASS}"
  status_line "/laser/scan rate>0" "${LASER_RATE}" "${LASER_PASS}"
  status_line "/livox/imu rate>0" "${IMU_RATE}" "${IMU_PASS}"
  status_line "/points_raw width>0" "${POINTS_WIDTH}" "${POINTS_PASS}"
  status_line "/livox/lidar point_num>0" "${LIVOX_POINT_NUM} (rate=${LIVOX_RATE})" "${LIVOX_PASS}"
  status_line "/cloud_registered width>0 + rate>0" "width=${CLOUD_WIDTH} rate=${CLOUD_RATE}" "${CLOUD_PASS}"
  status_line "reflectivity_variance>0" "${REFLECTIVITY_VARIANCE}" "${REFL_PASS}"
  echo
  echo "PASS_COUNT=${PASS_COUNT}"
  echo "FAIL_COUNT=${FAIL_COUNT}"
} | tee "${EVIDENCE_DIR}/check-summary.txt"

if [ "${FAIL_COUNT}" -gt 0 ]; then
  exit 1
fi
