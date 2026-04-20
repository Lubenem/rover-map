# rover-map
Reproducible Docker workspace for FAST-LIVO2 rover mapping experiments.

## Summary
- Objective completed: FAST-LIVO2 running on PX4 + Gazebo rover, driven through standard map, point cloud visible in RViz.
- Rover model: `rover_no_velodyne_rplidar_imu.sdf`
- World: `warehouse.world`
- Pipeline: `/laser/scan -> /points_raw -> /livox/lidar`, `/imu -> /livox/imu`, output `/cloud_registered`
- Runtime override: `/preprocess/blind=0.1`

## Media
- Demo video: `https://drive.google.com/file/d/1MLDMqBAZNfSqWKYbwTeoPaQuRdHAEYTY/view?usp=sharing`
- Screenshots: not provided (video-only submission)

## Note
- Rover motion in demo is deterministic via `tools/submission_drive.py`.

Thank you for your review.

-- 

## What this includes
- ROS1 Noetic Ubuntu 20.04 dev container
- Bootstrap script for FAST-LIVO2 + rpg_vikit + Sophus
- Makefile shortcuts for build/up/shell/bootstrap/tests

## Quick start

```bash
cd ~/projects/rover-map
make docker-build
make docker-up
make bootstrap
make test-env
```

Enter container shell:

```bash
make docker-shell
```

## Notes
- Container name: `rover-map`
- Compose service: `rover-map`
- Workspace mount: host `~/projects/rover-map` -> container `/workspace`
- Dependency repos live in `lib/` (host) -> `/workspace/lib` (container). Each dep keeps its own `.git`, but we do **not** commit them in this repo.
- Patches for deps live under `lib/patches/<repo>/`.
- This setup prepares environment only; simulation launch/config tuning is next step.

## Dependency remotes (cloned by bootstrap or manually)
- FAST-LIVO2: https://github.com/hku-mars/FAST-LIVO2.git
- rpg_vikit: https://github.com/xuankuzcr/rpg_vikit.git
- Sophus: https://github.com/strasdat/Sophus.git (checkout `a621ff` in bootstrap)
- PX4-Autopilot (manual clone): https://github.com/PX4/PX4-Autopilot.git (branch `v1.13.3`)

## Git Hygiene
Do not commit dependency repos cloned by bootstrap:
- `lib/fast-livo2`
- `lib/rpg_vikit`
- `lib/Sophus`
- `lib/PX4-Autopilot`
- `catkin_ws/src`

These are fetched automatically by `make bootstrap` (except PX4-Autopilot, which we place manually in `lib/`).

If they were staged accidentally:

```bash
git rm --cached -r lib/fast-livo2 lib/rpg_vikit lib/Sophus lib/PX4-Autopilot catkin_ws/src
```

Patches you should keep in Git:
- `lib/patches/PX4-Autopilot/px4-sitl-ros1-lidar-imu.patch`
