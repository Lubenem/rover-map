#!/usr/bin/env bash
set -euo pipefail

# Phase D implementation for ROS2 + Gazebo Harmonic + PX4 runtime + ROS2 topic pipeline.

CMD="status"
if [ "${1:-}" = "start" ] || [ "${1:-}" = "stop" ] || [ "${1:-}" = "status" ]; then
  CMD="$1"
  shift || true
fi

HEADLESS=1
FOREGROUND=0
TARGET_OVERRIDE=""
WORLD_OVERRIDE=""
WAIT_TIMEOUT=120
REQUIRE_REAL_LIDAR=0
DRIVE_DEMO=0
DRIVE_DURATION=90

while [ $# -gt 0 ]; do
  case "$1" in
    --headless)
      HEADLESS=1
      ;;
    --gui)
      HEADLESS=0
      ;;
    --foreground)
      FOREGROUND=1
      ;;
    --target)
      shift
      TARGET_OVERRIDE="${1:-}"
      if [ -z "${TARGET_OVERRIDE}" ]; then
        echo "Missing value for --target" >&2
        exit 1
      fi
      ;;
    --world)
      shift
      WORLD_OVERRIDE="${1:-}"
      if [ -z "${WORLD_OVERRIDE}" ]; then
        echo "Missing value for --world" >&2
        exit 1
      fi
      ;;
    --timeout)
      shift
      WAIT_TIMEOUT="${1:-}"
      if ! [[ "${WAIT_TIMEOUT}" =~ ^[0-9]+$ ]]; then
        echo "--timeout expects integer seconds" >&2
        exit 1
      fi
      ;;
    --require-real-lidar)
      REQUIRE_REAL_LIDAR=1
      ;;
    --drive-demo)
      DRIVE_DEMO=1
      ;;
    --drive-duration)
      shift
      DRIVE_DURATION="${1:-}"
      if ! [[ "${DRIVE_DURATION}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo "--drive-duration expects numeric seconds" >&2
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

RUNTIME_DIR="/workspace/.submission_runtime_ros2"
LOG_DIR="${RUNTIME_DIR}/logs"
ENV_FILE="${RUNTIME_DIR}/env.sh"
PID_FILE="${RUNTIME_DIR}/pids.txt"
STATUS_FILE="${RUNTIME_DIR}/status.txt"
TARGETS_FILE="${RUNTIME_DIR}/px4_targets.txt"
GZ_TARGETS_FILE="${RUNTIME_DIR}/px4_gz_targets.txt"

PX4_DIR="${PX4_DIR:-/workspace/lib/PX4-Autopilot-ros2}"
if [ ! -d "${PX4_DIR}" ] && [ -d "/workspace/lib/PX4-Autopilot" ]; then
  PX4_DIR="/workspace/lib/PX4-Autopilot"
fi

PX4_LOG="${LOG_DIR}/px4_gz.log"
BRIDGE_LOG="${LOG_DIR}/ros_gz_bridge.log"
SCAN_LOG="${LOG_DIR}/scan_to_cloud_ros2.log"
LIVOX_LOG="${LOG_DIR}/points_to_livox_ros2.log"
IMU_RELAY_LOG="${LOG_DIR}/imu_relay_ros2.log"
LASER_RELAY_LOG="${LOG_DIR}/laser_scan_relay_ros2.log"
SYNTH_LIDAR_LOG="${LOG_DIR}/synthetic_lidar_ros2.log"
MAPPER_LOG="${LOG_DIR}/fast_livo_mapper.log"
MAPPER_BUILD_LOG="${LOG_DIR}/fast_livo_build.log"
TOPICS_LOG="${LOG_DIR}/gz_topics.log"
DRIVE_LOG="${LOG_DIR}/submission_drive_ros2.log"
MAPPER_CONFIG="/workspace/config/fast_livo_ros2_rover.yaml"
CAMERA_CONFIG="/workspace/lib/FAST-LIVO2-ROS2/config/camera_pinhole.yaml"

DEFAULT_TARGET="${PX4_SIM_MODEL:-gz_rover_differential}"
DEFAULT_WORLD="${WORLD_OVERRIDE:-${PX4_GZ_WORLD:-rover}}"

SUBMISSION_WORLD_NAME=""
SUBMISSION_MODEL_NAME=""
IMU_GZ_TOPIC=""
IMU_GZ_TYPE=""
LIDAR_GZ_TOPIC=""
LIDAR_GZ_TYPE=""
LIDAR_SOURCE="gazebo"
LIVOX_RATE="0"
IMU_RATE="0"
CLOUD_RATE="0"
CLOUD_WIDTH="0"

source_ros2() {
  set +u
  source /opt/ros/humble/setup.bash
  if [ -f /workspace/colcon_ws/install/setup.bash ]; then
    source /workspace/colcon_ws/install/setup.bash
  fi
  set -u
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

cleanup_stack_processes() {
  pkill -f "${PX4_DIR}/build/px4_sitl_default/bin/px4" 2>/dev/null || true
  pkill -f "gz sim .*${PX4_DIR}/Tools/simulation/gz/worlds" 2>/dev/null || true
  pkill -f "make px4_sitl gz_" 2>/dev/null || true
  pkill -f "/ros_gz_bridge/parameter_bridge" 2>/dev/null || true
  pkill -f "/workspace/tools/scan_to_cloud_ros2.py" 2>/dev/null || true
  pkill -f "/workspace/tools/points_to_livox_ros2.py" 2>/dev/null || true
  pkill -f "/workspace/tools/imu_relay_ros2.py" 2>/dev/null || true
  pkill -f "/workspace/tools/laser_scan_relay_ros2.py" 2>/dev/null || true
  pkill -f "/workspace/tools/synthetic_lidar_ros2.py" 2>/dev/null || true
  pkill -f "/workspace/tools/submission_drive_ros2.py" 2>/dev/null || true
  pkill -f "fastlivo_mapping" 2>/dev/null || true
}

ensure_px4_python_deps() {
  if python3 - <<'PY'
import importlib.util
required = ["symforce.symbolic", "jsonschema", "future"]
missing = [m for m in required if importlib.util.find_spec(m) is None]
raise SystemExit(1 if missing else 0)
PY
  then
    return 0
  fi

  echo "Installing missing PX4 Python dependencies (symforce/jsonschema/future) ..."
  python3 -m pip install --user --no-cache-dir \
    'numpy<2.0' \
    symforce \
    jsonschema \
    future
}

resolve_px4_target() {
  local requested="${TARGET_OVERRIDE:-${DEFAULT_TARGET}}"
  local airframes_dir="${PX4_DIR}/ROMFS/px4fmu_common/init.d-posix/airframes"
  mkdir -p "${RUNTIME_DIR}" "${LOG_DIR}"

  if [ ! -d "${airframes_dir}" ]; then
    return 1
  fi

  find "${airframes_dir}" -maxdepth 1 -type f -printf '%f\n' \
    | sed -nE 's/^[0-9]+_(gz_[A-Za-z0-9_]+)$/\1/p' \
    | sort -u >"${GZ_TARGETS_FILE}"

  (
    cd "${PX4_DIR}"
    make list_config_targets >"${TARGETS_FILE}"
  )

  if [ -s "${GZ_TARGETS_FILE}" ] && grep -qx "${requested}" "${GZ_TARGETS_FILE}"; then
    echo "${requested}"
    return 0
  fi

  local rover_target
  rover_target="$(grep '^gz_.*rover' "${GZ_TARGETS_FILE}" | head -n 1 || true)"
  if [ -n "${rover_target}" ]; then
    echo "${rover_target}"
    return 0
  fi

  local any_gz
  any_gz="$(head -n 1 "${GZ_TARGETS_FILE}" || true)"
  if [ -n "${any_gz}" ]; then
    echo "${any_gz}"
    return 0
  fi

  return 1
}

prepare_rover_lidar_overlay() {
  local target="$1"
  local model="${target#gz_}"
  local src_model_dir="${PX4_DIR}/Tools/simulation/gz/models/${model}"
  local target_sdf="${src_model_dir}/model.sdf"

  if [ ! -d "${src_model_dir}" ]; then
    return 0
  fi

  # Only patch rover-style models in this phase.
  if [[ "${model}" != rover_* ]] && [[ "${model}" != r1_rover* ]]; then
    return 0
  fi

  python3 - "${target_sdf}" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()

snippet = """
      <sensor name="submission_lidar_sensor" type="gpu_lidar">
        <gz_frame_id>base_link</gz_frame_id>
        <pose relative_to="base_link">0.3 0 0.25 0 0 0</pose>
        <update_rate>15</update_rate>
        <ray>
          <scan>
            <horizontal>
              <samples>720</samples>
              <resolution>1</resolution>
              <min_angle>-3.14159</min_angle>
              <max_angle>3.14159</max_angle>
            </horizontal>
          </scan>
          <range>
            <min>0.10</min>
            <max>50.0</max>
            <resolution>0.01</resolution>
          </range>
        </ray>
        <always_on>1</always_on>
        <visualize>true</visualize>
      </sensor>
"""

sensor_pattern = re.compile(
    r"\s*<sensor\s+name=['\"]submission_lidar_sensor['\"].*?</sensor>\s*",
    re.S,
)
if sensor_pattern.search(text):
    text = sensor_pattern.sub("\n" + snippet + "\n", text, count=1)
    path.write_text(text)
    sys.exit(0)

pattern = re.compile(r"(<link name=['\"]base_link['\"]>)(.*?)(</link>)", re.S)
match = pattern.search(text)
if not match:
    print("Could not find base_link in model.sdf", file=sys.stderr)
    sys.exit(1)

body = match.group(2).rstrip() + "\n" + snippet + "\n    "
patched = text[:match.start()] + match.group(1) + body + match.group(3) + text[match.end():]
path.write_text(patched)
PY
}

wait_for_stack_ready() {
  local launcher_pid="$1"
  local tries=0

  while [ "${tries}" -lt "${WAIT_TIMEOUT}" ]; do
    if pgrep -f "${PX4_DIR}/build/px4_sitl_default/bin/px4" >/dev/null 2>&1 \
      && pgrep -f "gz sim .*${PX4_DIR}/Tools/simulation/gz/worlds" >/dev/null 2>&1 \
      && grep -Eq "INFO  \\[gz_bridge\\] world:|Startup script returned successfully" "${PX4_LOG}"; then
      return 0
    fi

    if ! kill -0 "${launcher_pid}" 2>/dev/null \
      && ! pgrep -f "${PX4_DIR}/build/px4_sitl_default/bin/px4" >/dev/null 2>&1; then
      echo "PX4 launcher exited before PX4 process became ready. See ${PX4_LOG}" >&2
      return 1
    fi

    tries=$((tries + 1))
    sleep 1
  done

  return 1
}

extract_world_and_model() {
  local target="$1"
  local recent
  recent="$(tail -n 6000 "${PX4_LOG}" 2>/dev/null || true)"

  SUBMISSION_MODEL_NAME="$(printf '%s\n' "${recent}" | grep -Eo 'model: [^, ]+' | awk '{print $2}' | tail -n 1 || true)"
  SUBMISSION_WORLD_NAME="$(printf '%s\n' "${recent}" | grep -Eo 'world: [^, ]+' | awk '{print $2}' | tail -n 1 || true)"

  if [ -z "${SUBMISSION_MODEL_NAME}" ]; then
    SUBMISSION_MODEL_NAME="${target#gz_}_0"
  fi
  if [ -z "${SUBMISSION_WORLD_NAME}" ]; then
    SUBMISSION_WORLD_NAME="${DEFAULT_WORLD}"
  fi
}

discover_gz_topics() {
  local tries=0
  IMU_GZ_TOPIC=""
  LIDAR_GZ_TOPIC=""
  LIDAR_SOURCE="gazebo"

  while [ "${tries}" -lt 60 ]; do
    gz topic -l >"${TOPICS_LOG}"

    IMU_GZ_TOPIC="$(grep -E "^/world/${SUBMISSION_WORLD_NAME}/model/${SUBMISSION_MODEL_NAME}/.*imu_sensor/imu$" "${TOPICS_LOG}" | head -n 1 || true)"
    if [ -z "${IMU_GZ_TOPIC}" ]; then
      IMU_GZ_TOPIC="$(grep -E "^/world/${SUBMISSION_WORLD_NAME}/model/${SUBMISSION_MODEL_NAME}/.*imu" "${TOPICS_LOG}" | head -n 1 || true)"
    fi

    LIDAR_GZ_TOPIC="$(grep -E "^/world/${SUBMISSION_WORLD_NAME}/model/${SUBMISSION_MODEL_NAME}/.*/sensor/submission_lidar_sensor/(scan|points)$" "${TOPICS_LOG}" | head -n 1 || true)"
    if [ -z "${LIDAR_GZ_TOPIC}" ]; then
      LIDAR_GZ_TOPIC="$(grep -E "^/world/${SUBMISSION_WORLD_NAME}/model/${SUBMISSION_MODEL_NAME}/.*/sensor/.*/(scan|points)$" "${TOPICS_LOG}" | grep -E 'lidar|laser' | head -n 1 || true)"
    fi
    if [ -z "${LIDAR_GZ_TOPIC}" ]; then
      LIDAR_GZ_TOPIC="$(grep -E "^/world/${SUBMISSION_WORLD_NAME}/model/${SUBMISSION_MODEL_NAME}/.*/(scan|points)$" "${TOPICS_LOG}" | grep -E 'lidar|laser' | head -n 1 || true)"
    fi

    if [ -n "${IMU_GZ_TOPIC}" ] && [ -n "${LIDAR_GZ_TOPIC}" ]; then
      break
    fi

    tries=$((tries + 1))
    sleep 1
  done

  if [ -z "${IMU_GZ_TOPIC}" ]; then
    echo "Could not discover Gazebo IMU topic for model ${SUBMISSION_MODEL_NAME}" >&2
    return 1
  fi
  # Ensure the chosen lidar topic is actively publishing before bridging.
  # If Gazebo lidar is not active in this environment, fall back to synthetic scan.
  local lidar_candidates
  local lidar_rate
  local attempt
  local active_lidar_topic=""
  lidar_candidates="$(grep -E "^/world/${SUBMISSION_WORLD_NAME}/model/${SUBMISSION_MODEL_NAME}/.*/(scan|points)$" "${TOPICS_LOG}" | grep -E 'lidar|laser' || true)"
  if [ -z "${lidar_candidates}" ] && [ -n "${LIDAR_GZ_TOPIC}" ]; then
    lidar_candidates="${LIDAR_GZ_TOPIC}"
  fi

  for attempt in $(seq 1 15); do
    while read -r cand; do
      [ -n "${cand}" ] || continue
      lidar_rate="$(timeout 4 gz topic -f -t "${cand}" 2>/dev/null | awk '/average rate:/ {print $3; exit}' || true)"
      if awk -v x="${lidar_rate:-0}" 'BEGIN{ exit ! (x+0 > 0) }'; then
        active_lidar_topic="${cand}"
        break 2
      fi
    done <<<"${lidar_candidates}"
    sleep 1
  done

  if [ -n "${active_lidar_topic}" ]; then
    LIDAR_GZ_TOPIC="${active_lidar_topic}"
  else
    if [ "${REQUIRE_REAL_LIDAR}" -eq 1 ]; then
      echo "Gazebo LiDAR not publishing and --require-real-lidar is set." >&2
      echo "Failing instead of using synthetic fallback." >&2
      return 1
    fi
    echo "Gazebo LiDAR not publishing; switching to synthetic Phase D scan source." >&2
    LIDAR_SOURCE="synthetic"
    LIDAR_GZ_TOPIC="/phase_d/fallback_scan"
    LIDAR_GZ_TYPE="gz.msgs.LaserScan"
  fi

  IMU_GZ_TYPE="$(gz topic -i -t "${IMU_GZ_TOPIC}" | grep -Eo 'gz\.msgs\.[A-Za-z0-9_]+' | head -n 1 || true)"
  if [ "${LIDAR_SOURCE}" = "gazebo" ]; then
    LIDAR_GZ_TYPE="$(gz topic -i -t "${LIDAR_GZ_TOPIC}" | grep -Eo 'gz\.msgs\.[A-Za-z0-9_]+' | head -n 1 || true)"
  fi

  if [ "${IMU_GZ_TYPE}" != "gz.msgs.IMU" ]; then
    echo "Unexpected IMU Gazebo type on ${IMU_GZ_TOPIC}: ${IMU_GZ_TYPE}" >&2
    return 1
  fi
  if [ "${LIDAR_SOURCE}" = "gazebo" ] && [ "${LIDAR_GZ_TYPE}" != "gz.msgs.LaserScan" ]; then
    echo "Phase D expects a LaserScan LiDAR topic. Found ${LIDAR_GZ_TYPE} on ${LIDAR_GZ_TOPIC}" >&2
    return 1
  fi
}

probe_topic_raw() {
  local topic="$1"
  local msg_type="$2"
  local timeout_s="$3"
  local min_msgs="$4"
  local metric="${5:-none}"
  local out

  out="$(python3 /workspace/tools/ros2_topic_probe.py \
    --topic "${topic}" \
    --msg-type "${msg_type}" \
    --timeout "${timeout_s}" \
    --min-msgs "${min_msgs}" \
    --metric "${metric}")" || {
      echo "Probe failed for ${topic} (${msg_type}): ${out}" >&2
      return 1
    }

  echo "${out}"
}

probe_topic_value() {
  local topic="$1"
  local msg_type="$2"
  local timeout_s="$3"
  local min_msgs="$4"
  local metric="$5"
  local key="$6"
  local raw

  raw="$(probe_topic_raw "${topic}" "${msg_type}" "${timeout_s}" "${min_msgs}" "${metric}")" || return 1
  echo "${raw}" | awk -v k="${key}" '{
    for (i=1; i<=NF; i++) {
      if ($i ~ ("^" k "=")) {
        split($i, arr, "=");
        print arr[2];
        exit;
      }
    }
  }'
}

ensure_fast_livo_binary() {
  source_ros2
  if [ -x /workspace/colcon_ws/install/fast_livo/lib/fast_livo/fastlivo_mapping ]; then
    return 0
  fi

  echo "fast_livo binary not found; building package fast_livo ..."
  (
    set +u
    source /opt/ros/humble/setup.bash
    set -u
    cd /workspace/colcon_ws
    colcon build \
      --symlink-install \
      --event-handlers console_direct+ \
      --packages-select fast_livo \
      --cmake-args -DCMAKE_BUILD_TYPE=Release
  ) >"${MAPPER_BUILD_LOG}" 2>&1 || {
    echo "fast_livo build failed. See ${MAPPER_BUILD_LOG}" >&2
    return 1
  }

  source_ros2
  if [ ! -x /workspace/colcon_ws/install/fast_livo/lib/fast_livo/fastlivo_mapping ]; then
    echo "fast_livo binary still missing after build." >&2
    return 1
  fi
}

start_ros_pipeline() {
  source_ros2
  local -a bridge_args

  bridge_args=(
    "/clock@rosgraph_msgs/msg/Clock[gz.msgs.Clock"
    "${IMU_GZ_TOPIC}@sensor_msgs/msg/Imu[${IMU_GZ_TYPE}"
  )
  if [ "${LIDAR_SOURCE}" = "gazebo" ]; then
    bridge_args+=("${LIDAR_GZ_TOPIC}@sensor_msgs/msg/LaserScan[${LIDAR_GZ_TYPE}")
  else
    python3 /workspace/tools/synthetic_lidar_ros2.py \
      --output-topic "${LIDAR_GZ_TOPIC}" \
      >"${SYNTH_LIDAR_LOG}" 2>&1 &
    local synth_pid=$!
    echo "${synth_pid}" >>"${PID_FILE}"
  fi

  ros2 run ros_gz_bridge parameter_bridge \
    "${bridge_args[@]}" \
    >"${BRIDGE_LOG}" 2>&1 &
  local bridge_pid=$!
  echo "${bridge_pid}" >>"${PID_FILE}"

  python3 /workspace/tools/laser_scan_relay_ros2.py \
    --input-topic "${LIDAR_GZ_TOPIC}" \
    --output-topic /laser/scan \
    >"${LASER_RELAY_LOG}" 2>&1 &
  local relay_pid=$!
  echo "${relay_pid}" >>"${PID_FILE}"

  python3 /workspace/tools/scan_to_cloud_ros2.py \
    --input-topic /laser/scan \
    --output-topic /points_raw \
    >"${SCAN_LOG}" 2>&1 &
  local scan_pid=$!
  echo "${scan_pid}" >>"${PID_FILE}"

  python3 /workspace/tools/points_to_livox_ros2.py \
    --input-topic /points_raw \
    --output-topic /livox/lidar \
    >"${LIVOX_LOG}" 2>&1 &
  local livox_pid=$!
  echo "${livox_pid}" >>"${PID_FILE}"

  python3 /workspace/tools/imu_relay_ros2.py \
    --input-topic "${IMU_GZ_TOPIC}" \
    --output-topic /livox/imu \
    >"${IMU_RELAY_LOG}" 2>&1 &
  local imu_pid=$!
  echo "${imu_pid}" >>"${PID_FILE}"
}

verify_phase_d_topics() {
  local laser_rate
  local points_rate
  laser_rate="$(probe_topic_value /laser/scan sensor_msgs/msg/LaserScan 45 3 none rate)" || return 1
  points_rate="$(probe_topic_value /points_raw sensor_msgs/msg/PointCloud2 45 3 none rate)" || return 1
  LIVOX_RATE="$(probe_topic_value /livox/lidar livox_ros_driver2/msg/CustomMsg 45 3 none rate)" || return 1
  IMU_RATE="$(probe_topic_value /livox/imu sensor_msgs/msg/Imu 45 6 none rate)" || return 1

  awk -v x="${laser_rate}" 'BEGIN{ exit ! (x+0 > 0) }' || {
    echo "No positive rate on /laser/scan (rate=${laser_rate})" >&2
    return 1
  }

  awk -v x="${points_rate}" 'BEGIN{ exit ! (x+0 > 0) }' || {
    echo "No positive rate on /points_raw (rate=${points_rate})" >&2
    return 1
  }
  awk -v x="${LIVOX_RATE}" 'BEGIN{ exit ! (x+0 > 0) }' || {
    echo "No positive rate on /livox/lidar (rate=${LIVOX_RATE})" >&2
    return 1
  }
  awk -v x="${IMU_RATE}" 'BEGIN{ exit ! (x+0 > 0) }' || {
    echo "No positive rate on /livox/imu (rate=${IMU_RATE})" >&2
    return 1
  }
}

start_mapper() {
  source_ros2
  if [ ! -f "${MAPPER_CONFIG}" ]; then
    echo "Missing mapper config: ${MAPPER_CONFIG}" >&2
    return 1
  fi
  if [ ! -f "${CAMERA_CONFIG}" ]; then
    echo "Missing camera config: ${CAMERA_CONFIG}" >&2
    return 1
  fi
  ensure_fast_livo_binary || return 1

  ros2 run fast_livo fastlivo_mapping \
    --ros-args \
    --params-file "${MAPPER_CONFIG}" \
    --params-file "${CAMERA_CONFIG}" \
    -p use_sim_time:=true \
    >"${MAPPER_LOG}" 2>&1 &
  local mapper_pid=$!
  echo "${mapper_pid}" >>"${PID_FILE}"
}

verify_phase_e_topics() {
  CLOUD_RATE="$(probe_topic_value /cloud_registered sensor_msgs/msg/PointCloud2 90 3 none rate)" || return 1
  CLOUD_WIDTH="$(probe_topic_value /cloud_registered sensor_msgs/msg/PointCloud2 90 1 pointcloud_width width_max)" || return 1

  awk -v x="${CLOUD_RATE}" 'BEGIN{ exit ! (x+0 > 0) }' || {
    echo "No positive rate on /cloud_registered (rate=${CLOUD_RATE})" >&2
    return 1
  }

  awk -v x="${CLOUD_WIDTH}" 'BEGIN{ exit ! (x+0 > 0) }' || {
    echo "No positive width on /cloud_registered (width=${CLOUD_WIDTH})" >&2
    return 1
  }
}

start_drive_demo() {
  if [ "${DRIVE_DEMO}" -ne 1 ]; then
    return 0
  fi
  python3 /workspace/tools/submission_drive_ros2.py \
    --world "${SUBMISSION_WORLD_NAME}" \
    --model "${SUBMISSION_MODEL_NAME}" \
    --duration "${DRIVE_DURATION}" \
    --rate 6 \
    >"${DRIVE_LOG}" 2>&1 &
  local drive_pid=$!
  echo "${drive_pid}" >>"${PID_FILE}"
}

write_env_file() {
  local target="$1"
  mkdir -p "${RUNTIME_DIR}" "${LOG_DIR}"
  cat >"${ENV_FILE}" <<EOT
export ROS2_STACK_PHASE=G
export ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-42}
export GZ_VERSION=harmonic
export PX4_SIM_MODEL=${target}
export PX4_GZ_WORLD=${DEFAULT_WORLD}
export PX4_DIR=${PX4_DIR}
export SUBMISSION_RUNTIME_DIR=${RUNTIME_DIR}
export SUBMISSION_WORLD_NAME=${SUBMISSION_WORLD_NAME}
export SUBMISSION_MODEL_NAME=${SUBMISSION_MODEL_NAME}
export SUBMISSION_GZ_IMU_TOPIC=${IMU_GZ_TOPIC}
export SUBMISSION_GZ_LIDAR_TOPIC=${LIDAR_GZ_TOPIC}
export SUBMISSION_LIDAR_SOURCE=${LIDAR_SOURCE}
export SUBMISSION_MAPPER_CONFIG=${MAPPER_CONFIG}
export SUBMISSION_REQUIRE_REAL_LIDAR=${REQUIRE_REAL_LIDAR}
export SUBMISSION_DRIVE_DEMO=${DRIVE_DEMO}
export SUBMISSION_DRIVE_DURATION=${DRIVE_DURATION}
export SUBMISSION_GZ_SIM_RESOURCE_PATH=${GZ_SIM_RESOURCE_PATH:-}
EOT
}

write_status_file() {
  local target="$1"
  local px4_pid="$2"
  cat >"${STATUS_FILE}" <<EOT
status=running
phase=G
px4_target=${target}
headless=${HEADLESS}
px4_pid=${px4_pid}
runtime_dir=${RUNTIME_DIR}
logs=${LOG_DIR}
world_requested=${DEFAULT_WORLD}
world=${SUBMISSION_WORLD_NAME}
model=${SUBMISSION_MODEL_NAME}
imu_gz_topic=${IMU_GZ_TOPIC}
lidar_gz_topic=${LIDAR_GZ_TOPIC}
lidar_source=${LIDAR_SOURCE}
require_real_lidar=${REQUIRE_REAL_LIDAR}
drive_demo=${DRIVE_DEMO}
drive_duration=${DRIVE_DURATION}
livox_lidar_rate=${LIVOX_RATE}
livox_imu_rate=${IMU_RATE}
cloud_registered_rate=${CLOUD_RATE}
cloud_registered_width=${CLOUD_WIDTH}
started_at=$(date --iso-8601=seconds)
EOT
}

start_stack() {
  if [ ! -d "${PX4_DIR}" ]; then
    echo "Missing PX4 repository at ${PX4_DIR}" >&2
    return 1
  fi

  if ! command -v gz >/dev/null 2>&1; then
    echo "Missing gz CLI in container PATH" >&2
    return 1
  fi

  ensure_px4_python_deps

  local px4_target
  if ! px4_target="$(resolve_px4_target)"; then
    echo "No Gazebo Harmonic target found in PX4 airframes." >&2
    echo "Your PX4 checkout appears too old or incomplete for gz_* targets." >&2
    echo "See ${GZ_TARGETS_FILE} and ${TARGETS_FILE} for diagnostics." >&2
    return 1
  fi

  prepare_rover_lidar_overlay "${px4_target}"

  mkdir -p "${RUNTIME_DIR}" "${LOG_DIR}"
  : > "${PID_FILE}"
  : > "${PX4_LOG}"
  : > "${BRIDGE_LOG}"
  : > "${SCAN_LOG}"
  : > "${LIVOX_LOG}"
  : > "${IMU_RELAY_LOG}"
  : > "${LASER_RELAY_LOG}"
  : > "${SYNTH_LIDAR_LOG}"
  : > "${MAPPER_LOG}"
  : > "${MAPPER_BUILD_LOG}"
  : > "${TOPICS_LOG}"
  : > "${DRIVE_LOG}"

  (
    cd "${PX4_DIR}"
    if [ "${HEADLESS}" -eq 1 ]; then
      HEADLESS=1 PX4_NO_PXH=1 PX4_GZ_WORLD="${DEFAULT_WORLD}" PX4_SIM_MODEL="${px4_target}" \
        make px4_sitl "${px4_target}" >"${PX4_LOG}" 2>&1
    else
      PX4_NO_PXH=1 PX4_GZ_WORLD="${DEFAULT_WORLD}" PX4_SIM_MODEL="${px4_target}" \
        make px4_sitl "${px4_target}" >"${PX4_LOG}" 2>&1
    fi
  ) &
  local px4_pid=$!
  echo "${px4_pid}" >>"${PID_FILE}"

  if ! wait_for_stack_ready "${px4_pid}"; then
    echo "Timed out waiting for PX4 + Gazebo Harmonic stack readiness." >&2
    echo "See ${PX4_LOG} for details." >&2
    return 1
  fi

  pgrep -f "${PX4_DIR}/build/px4_sitl_default/bin/px4" >>"${PID_FILE}" 2>/dev/null || true
  pgrep -f "gz sim .*${PX4_DIR}/Tools/simulation/gz/worlds" >>"${PID_FILE}" 2>/dev/null || true

  extract_world_and_model "${px4_target}"

  if ! discover_gz_topics; then
    return 1
  fi

  start_ros_pipeline

  if ! verify_phase_d_topics; then
    return 1
  fi

  start_mapper

  if ! verify_phase_e_topics; then
    return 1
  fi

  start_drive_demo

  sort -u -o "${PID_FILE}" "${PID_FILE}"
  write_env_file "${px4_target}"
  write_status_file "${px4_target}" "${px4_pid}"

  echo "ROS2 stack started (Phases D/E/G)."
  echo "PX4 target: ${px4_target}"
  echo "Requested world: ${DEFAULT_WORLD}"
  echo "World: ${SUBMISSION_WORLD_NAME}"
  echo "Model: ${SUBMISSION_MODEL_NAME}"
  echo "LiDAR source: ${LIDAR_SOURCE}"
  echo "LiDAR topic: ${LIDAR_GZ_TOPIC} (${LIDAR_GZ_TYPE})"
  echo "Require real lidar: ${REQUIRE_REAL_LIDAR}"
  echo "Drive demo: ${DRIVE_DEMO} (duration=${DRIVE_DURATION}s)"
  echo "IMU topic: ${IMU_GZ_TOPIC} (${IMU_GZ_TYPE})"
  echo "Rates: /livox/lidar=${LIVOX_RATE} /livox/imu=${IMU_RATE}"
  echo "Mapper: /cloud_registered rate=${CLOUD_RATE} width=${CLOUD_WIDTH}"
  echo "Runtime env: ${ENV_FILE}"
  echo "Logs dir: ${LOG_DIR}"

  if [ "${FOREGROUND}" -eq 1 ]; then
    trap 'cleanup_stack_processes; cleanup_by_pidfile' INT TERM EXIT
    wait "${px4_pid}"
  fi
}

stop_stack() {
  cleanup_stack_processes
  cleanup_by_pidfile
  rm -f "${STATUS_FILE}" "${ENV_FILE}" "${PID_FILE}"
  echo "ROS2 stack stopped."
}

status_stack() {
  if [ -f "${STATUS_FILE}" ] && [ -f "${PID_FILE}" ]; then
    local running=0
    while read -r p; do
      [ -n "${p}" ] || continue
      if kill -0 "${p}" 2>/dev/null; then
        running=1
        break
      fi
    done <"${PID_FILE}"
    if [ "${running}" -eq 1 ]; then
      cat "${STATUS_FILE}"
      return 0
    fi
    echo "status=stale"
    cat "${STATUS_FILE}" || true
    return 1
  elif [ -f "${STATUS_FILE}" ]; then
    cat "${STATUS_FILE}"
  else
    echo "status=stopped"
  fi
}

case "${CMD}" in
  start)
    stop_stack >/dev/null 2>&1 || true
    if ! start_stack; then
      stop_stack >/dev/null 2>&1 || true
      exit 1
    fi
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
