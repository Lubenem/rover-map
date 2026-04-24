#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PX4_ROS2_DIR="${ROOT_DIR}/lib/PX4-Autopilot-ros2"
PX4_BRANCH_REF="${1:-release/1.17}"
PX4_REMOTE_URL="${PX4_REMOTE_URL:-https://github.com/PX4/PX4-Autopilot.git}"
PX4_BRANCH_CLONE="${PX4_BRANCH_REF#origin/}"

is_worktree_checkout() {
  [[ -f "${PX4_ROS2_DIR}/.git" ]] && grep -q '/worktrees/' "${PX4_ROS2_DIR}/.git"
}

clone_fresh() {
  echo "Cloning ROS2 PX4 repo into ${PX4_ROS2_DIR} (${PX4_BRANCH_CLONE}) ..."
  git clone --branch "${PX4_BRANCH_CLONE}" --recursive "${PX4_REMOTE_URL}" "${PX4_ROS2_DIR}"
}

if [[ ! -e "${PX4_ROS2_DIR}" ]]; then
  clone_fresh
elif is_worktree_checkout; then
  # Worktree gitdirs break when used from inside /workspace container paths.
  echo "Detected worktree checkout at ${PX4_ROS2_DIR}; recreating as standalone clone ..."
  rm -rf "${PX4_ROS2_DIR}"
  clone_fresh
else
  echo "Updating existing ROS2 PX4 clone at ${PX4_ROS2_DIR} ..."
  git -C "${PX4_ROS2_DIR}" fetch origin --tags --prune
  if git -C "${PX4_ROS2_DIR}" show-ref --verify --quiet "refs/remotes/origin/${PX4_BRANCH_CLONE}"; then
    git -C "${PX4_ROS2_DIR}" checkout "${PX4_BRANCH_CLONE}" || git -C "${PX4_ROS2_DIR}" checkout -b "${PX4_BRANCH_CLONE}" "origin/${PX4_BRANCH_CLONE}"
    git -C "${PX4_ROS2_DIR}" pull --ff-only origin "${PX4_BRANCH_CLONE}"
  else
    git -C "${PX4_ROS2_DIR}" checkout --detach "${PX4_BRANCH_REF}"
  fi
fi

echo "Syncing/updating submodules in ROS2 PX4 clone ..."
git -C "${PX4_ROS2_DIR}" submodule sync --recursive
git -C "${PX4_ROS2_DIR}" submodule update --init --recursive

echo "ROS2 PX4 clone ready:"
git -C "${PX4_ROS2_DIR}" rev-parse --short HEAD
git -C "${PX4_ROS2_DIR}" describe --tags --always
