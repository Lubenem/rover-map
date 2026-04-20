# Submission Guide

## Verification Status
- New report reviewed: `context/test-task-130426/plan/communication/agent/sage-advice-7-followup.md`
- Scripts reviewed:
  - `tools/submission_run.sh`
  - `tools/submission_drive.py`
  - `tools/submission_check.sh`
- Independent rerun completed and passed:
  - `context/test-task-130426/plan/communication/agent/submission-check-20260419-191530/check-summary.txt`
- Result: `PASS 5/5`
- World selected in rerun: `warehouse.world`

## Ready-for-Submission Decision
Yes. You can proceed with final submission documents and media capture.

## Important Caveat (document this clearly)
- Rover motion in this demo is executed by `tools/submission_drive.py` using Gazebo model-state updates for a deterministic route.

## Final Submission Workflow
1. Follow the run instructions in `context/test-task-130426/plan/report/submission-operator-guide.md`.
2. Run and capture:
   - `/workspace/tools/submission_run.sh`
   - `python3 /workspace/tools/submission_drive.py --duration 90`
   - `/workspace/tools/submission_check.sh`
3. Record one video showing:
   - stack start output,
   - rover moving in Gazebo standard world,
   - RViz map growth (`/cloud_registered`),
   - final PASS table from `submission_check.sh`.
4. Take 2 screenshots:
   - Gazebo with rover in motion.
   - RViz with accumulated point cloud map.
5. Fill the template:
   - `context/test-task-130426/plan/report/submission-evidence-template.md`
   - Include run datetime, world, model, commands, topic rates/widths, evidence paths, and media links.
6. Add a concise final summary in your submission:
   - task objective,
   - pipeline used (`/laser/scan -> /points_raw -> /livox/lidar`, `/imu -> /livox/imu`, FAST-LIVO2 output `/cloud_registered`),
   - final evidence path and PASS result,
   - caveat above.

## Recommended Evidence to Reference
- Latest verified check summary:
  - `context/test-task-130426/plan/communication/agent/submission-check-20260419-191530/check-summary.txt`
- Operator runbook:
  - `context/test-task-130426/plan/report/submission-operator-guide.md`
- Evidence template:
  - `context/test-task-130426/plan/report/submission-evidence-template.md`
