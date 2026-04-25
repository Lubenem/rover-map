# Advise 1

## Verdict

Do not submit the current ROS2 fix yet.

The ROS2 + Gazebo Harmonic + PX4 environment is real, FAST-LIVO2 runs, `/cloud_registered` publishes, and the color/intensity fix is measurable. But the final pipeline still uses synthetic LiDAR. That means the main client requirement is not fully satisfied.

Client request:
- use `ROS2 + Gazebo Harmonic + PX4`
- fix Fast-LIVO2 output so it is color, not grayscale

Current state:
- ROS2/Harmonic/PX4: partially satisfied
- colored output: satisfied at the pipeline level
- real Gazebo/PX4 rover LiDAR: not satisfied

## Evidence From Fresh Verification

I reran the current stack on 2026-04-25:

```bash
make docker-up-ros2
make test-env-ros2
make submission-stop-ros2 || true
make submission-start-ros2
make submission-status-ros2
make submission-check-ros2
make submission-stop-ros2
```

Environment check passed:
- ROS2 CLI available
- Gazebo Harmonic reported `8.11.0`
- PX4 listed rover targets including `gz_rover_differential`

The full stack started, but startup printed:

```text
Gazebo LiDAR not publishing; switching to synthetic Phase D scan source.
LiDAR source: synthetic
LiDAR topic: /phase_d/fallback_scan (gz.msgs.LaserScan)
```

The status/check confirmed the same:

```text
lidar_source=synthetic
lidar_topic=/phase_d/fallback_scan
PASS_COUNT=6
FAIL_COUNT=0
```

Latest evidence path from this verification:

```text
artifacts/ros2/submission-check-20260425-135701/check-summary.txt
```

The pass table is therefore not enough. It proves the bridge/mapper/color pipeline works, but it does not prove real rover LiDAR from Gazebo Harmonic.

## Manual Submission Guide Review

`manual-submission-video-guide-ros2.md` is not final-submission-safe in its current form.

It correctly warns that runtime may show:

```text
lidar_source=synthetic
```

But for the requested fixes, this should be treated as a blocker, not a reviewer note. A strict reviewer can reject it because the assignment asks for PX4 + Gazebo rover LiDAR, not a fallback scan publisher.

Update the guide only after the final run shows:

```text
lidar_source=gazebo
```

## Technical Findings

The runner attempts to solve LiDAR by adding a `submission_lidar_sensor` to the PX4 rover model:

```text
tools/submission_run_ros2.sh
lib/PX4-Autopilot-ros2/Tools/simulation/gz/models/rover_differential/model.sdf
```

But the live Gazebo topic list does not show this sensor publishing. It only shows discovered LiDAR-like topics with no publishers:

```text
/world/rover/model/rover_differential_0/link/lidar_sensor_link/sensor/lidar/scan
/world/rover/model/rover_differential_0/link/link/sensor/lidar_2d_v2/scan
```

`gz topic -i` reports no publishers on those topics.

One suspicious mismatch:
- local rover patch uses `<sensor name="submission_lidar_sensor" type="lidar">` with a `<lidar>` block
- working PX4/Gazebo Harmonic examples in this checkout use `<sensor ... type="gpu_lidar">` with a `<ray>` block, for example `lidar_2d_v2/model.sdf`

The existing overlay logic also has a source-of-truth problem:
- if the source model already contains `submission_lidar_sensor`, `prepare_rover_lidar_overlay()` returns early
- that can bypass the overlay export path and hide whether the patched model is actually the one being spawned

## Correct Next Direction

### 1. Make synthetic fallback impossible in final mode

Add a strict mode to `tools/submission_run_ros2.sh`, for example:

```bash
--require-real-lidar
```

In this mode:
- if Gazebo LiDAR has no active publisher, fail immediately
- do not start `tools/synthetic_lidar_ros2.py`
- do not write a passing status

Also update `tools/submission_check_ros2.sh` so final checks fail when:

```text
SUBMISSION_LIDAR_SOURCE != gazebo
```

This prevents a false PASS.

### 2. Fix and prove the Gazebo LiDAR sensor alone

Before starting bridges or FAST-LIVO2, prove the Gazebo sensor directly.

Use a minimal diagnostic loop:

```bash
make submission-stop-ros2 || true
make docker-shell-ros2
```

Inside container:

```bash
cd /workspace/lib/PX4-Autopilot-ros2
HEADLESS=1 PX4_NO_PXH=1 PX4_GZ_WORLD=rover PX4_SIM_MODEL=gz_rover_differential \
  make px4_sitl gz_rover_differential
```

In another container shell:

```bash
gz topic -l | sort | grep -E 'lidar|laser|scan'
gz topic -i -t /world/rover/model/rover_differential_0/link/base_link/sensor/submission_lidar_sensor/scan
timeout 8 gz topic -f -t /world/rover/model/rover_differential_0/link/base_link/sensor/submission_lidar_sensor/scan
timeout 5 gz topic -e -n 1 -t /world/rover/model/rover_differential_0/link/base_link/sensor/submission_lidar_sensor/scan
```

Do not continue until this direct Gazebo check shows:
- publisher exists
- frequency > 0
- one scan message can be echoed

### 3. Patch the rover model using the known Harmonic sensor pattern

Use the local PX4 Harmonic examples as the reference, not the current `<sensor type="lidar">` block.

Reference files:

```text
lib/PX4-Autopilot-ros2/Tools/simulation/gz/models/lidar_2d_v2/model.sdf
lib/PX4-Autopilot-ros2/Tools/simulation/gz/models/x500_lidar_front/model.sdf
```

Preferred patch shape for the rover:

```xml
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
```

If headless GPU LiDAR still does not publish, test `type="gpu_lidar"` with GUI once. If it only works with GUI, record that and decide whether final submission must run with GUI or whether a CPU-compatible sensor variant is needed.

### 4. Clean up source-of-truth handling

Pick one source of truth:

Option A:
- patch `lib/PX4-Autopilot-ros2/Tools/simulation/gz/models/rover_differential/model.sdf`
- document that it is a project-local PX4 dependency patch

Option B:
- keep the PX4 checkout untouched
- always build and export a model override under `.submission_runtime_ros2/model_overrides`
- ensure `GZ_SIM_RESOURCE_PATH` is exported before PX4 starts

Do not keep both partial approaches. The current mixture makes it unclear which model Gazebo actually spawned.

### 5. Final acceptance gate

The final run is acceptable only if all are true:

```text
lidar_source=gazebo
lidar_gz_topic=/world/.../submission_lidar_sensor/scan
/laser/scan rate>0 PASS
/points_raw width>0 PASS
/livox/lidar point_num>0 PASS
/cloud_registered width>0 + rate>0 PASS
reflectivity_variance>0 PASS
PASS_COUNT=7
FAIL_COUNT=0
```

Add the real-LiDAR source check as the seventh row.

## What Is Already Good

Keep these parts:
- ROS2/Humble container with Gazebo Harmonic
- PX4 `gz_rover_differential` startup
- FAST-LIVO2 ROS2 build and mapper launch
- `points_to_livox_ros2.py` reflectivity generation
- `config/fast_livo_ros2_color.rviz`
- `ros2_topic_probe.py` metrics

These are useful and mostly correct. The remaining blocker is real Gazebo LiDAR publication.

## One-Sentence Instruction

Stop treating synthetic LiDAR as a pass condition; make it a hard failure, fix the rover Gazebo Harmonic LiDAR until `gz topic` proves a real scan publisher, then rerun the full FAST-LIVO2/color pipeline with `lidar_source=gazebo`.
