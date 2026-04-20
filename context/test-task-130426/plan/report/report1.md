# Step 1 – Foundation (rover-map)

What we set up
- Named the project and container `rover-map`; repo root at `~/projects/rover-map`.
- Dockerized the environment (Ubuntu 20.04, ROS Noetic, build tools). Compose keeps the container alive via `sleep infinity`.
- Added helper scripts: `infra/docker/scripts/entrypoint.sh` (ROS-friendly shell), `bootstrap.sh` (clone + build deps), `test-env.sh` (sanity check).
- Fixed image build by switching `python3-catkin-tools` to `pip install catkin-tools`.
- Patched Sophus to build on 20.04 (setter calls for unit complex components).
- Cleaned git hygiene: ignore nested cloned deps and avoid committing them.

How to recreate
1) From host repo root `~/projects/rover-map`:
   - Build image: `make docker-build`
   - Start container: `make docker-up`
2) Enter container shell: `make docker-shell`
3) Inside container `/workspace`:
   - Bootstrap deps: `make bootstrap`
   - Verify env: `make test-env`
4) Git hygiene: keep `lib/fast-livo2`, `lib/Sophus`, `lib/rpg_vikit`, `lib/PX4-Autopilot` untracked (already in `.gitignore`).

Artifacts/paths
- Dockerfile: `infra/docker/Dockerfile`
- Compose: `infra/docker/docker-compose.yml`
- Scripts: `infra/docker/scripts/{entrypoint.sh,bootstrap.sh,test-env.sh}`
- Docs: `plan/step1-foundation.md`, `plan/runbook.md` (rooted under `~/projects/config/...`).
