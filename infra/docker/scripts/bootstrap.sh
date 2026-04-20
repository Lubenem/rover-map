#!/usr/bin/env bash
set -euo pipefail

set +u
source /opt/ros/noetic/setup.bash
set -u

PROJECT_ROOT="/workspace"
SRC_DIR="${PROJECT_ROOT}/lib"
CATKIN_WS="${PROJECT_ROOT}/catkin_ws"
CATKIN_SRC="${CATKIN_WS}/src"
SOPHUS_DIR="${SRC_DIR}/Sophus"
FAST_LIVO2_DIR="${SRC_DIR}/fast-livo2"
VIKIT_DIR="${SRC_DIR}/rpg_vikit"

mkdir -p "${SRC_DIR}" "${CATKIN_SRC}"

if [[ ! -d "${FAST_LIVO2_DIR}/.git" ]]; then
  git clone https://github.com/hku-mars/FAST-LIVO2.git "${FAST_LIVO2_DIR}"
fi

if [[ ! -d "${VIKIT_DIR}/.git" ]]; then
  git clone https://github.com/xuankuzcr/rpg_vikit.git "${VIKIT_DIR}"
fi

if [[ ! -d "${SOPHUS_DIR}/.git" ]]; then
  git clone https://github.com/strasdat/Sophus.git "${SOPHUS_DIR}"
fi

pushd "${SOPHUS_DIR}" >/dev/null
git fetch --all --tags
git checkout a621ff

# Compatibility patch for old Sophus commit with modern std::complex API.
# On newer compilers, real()/imag() assignment is invalid; use setter overloads.
if grep -q "unit_complex_\\.real() = 1\\.;" sophus/so2.cpp; then
  sed -i 's/unit_complex_\.real() = 1\.;/unit_complex_.real(1.);/' sophus/so2.cpp
fi
if grep -q "unit_complex_\\.imag() = 0\\.;" sophus/so2.cpp; then
  sed -i 's/unit_complex_\.imag() = 0\.;/unit_complex_.imag(0.);/' sophus/so2.cpp
fi

mkdir -p build
cd build
cmake ..
make -j"$(nproc)"
sudo make install
popd >/dev/null

ln -sfn "${FAST_LIVO2_DIR}" "${CATKIN_SRC}/FAST-LIVO2"
ln -sfn "${VIKIT_DIR}" "${CATKIN_SRC}/rpg_vikit"

pushd "${CATKIN_WS}" >/dev/null
catkin_make
popd >/dev/null

if ! grep -q "source /opt/ros/noetic/setup.bash" ~/.bashrc; then
  echo "source /opt/ros/noetic/setup.bash" >> ~/.bashrc
fi

if ! grep -q "source /workspace/catkin_ws/devel/setup.bash" ~/.bashrc; then
  echo "source /workspace/catkin_ws/devel/setup.bash" >> ~/.bashrc
fi

echo "Bootstrap completed."
echo "Use: source /workspace/catkin_ws/devel/setup.bash"
