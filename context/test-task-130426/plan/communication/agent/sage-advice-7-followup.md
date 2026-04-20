# Sage Advice 7 Follow-up (Submission Ready)

## New assets
- `/workspace/tools/submission_run.sh`
- `/workspace/tools/submission_drive.py`
- `/workspace/tools/submission_check.sh`
- `/workspace/context/test-task-130426/plan/report/submission-operator-guide.md`
- `/workspace/context/test-task-130426/plan/report/submission-evidence-template.md`

## One-command flow
- start stack: `/workspace/tools/submission_run.sh`
- start motion: `python3 /workspace/tools/submission_drive.py --duration 90`
- run checks: `/workspace/tools/submission_check.sh`

## Latest dry-run evidence
- check evidence dir: `/workspace/context/test-task-130426/plan/communication/agent/submission-check-20260419-191042`
- check summary: `/workspace/context/test-task-130426/plan/communication/agent/submission-check-20260419-191042/check-summary.txt`
- stack logs: `/workspace/.submission_runtime/logs`

Dry-run result:
- all required checks PASS (5/5)
- standard world selected: `warehouse.world`

## Residual risk
- First startup on a cold cache can take ~1-2 minutes before Gazebo ROS services become available in `warehouse.world`.
