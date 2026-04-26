#!/usr/bin/env python3
"""
Deterministic rover motion helper for ROS2 + Gazebo Harmonic submission runs.
Moves rover with Gazebo set_pose service for reliable demo motion.
"""

import argparse
import math
import subprocess
import sys
import time
from typing import Iterable, Tuple


def log(msg: str) -> None:
    print(msg, flush=True)


def yaw_from_quat(qx: float, qy: float, qz: float, qw: float) -> float:
    siny_cosp = 2.0 * (qw * qz + qx * qy)
    cosy_cosp = 1.0 - 2.0 * (qy * qy + qz * qz)
    return math.atan2(siny_cosp, cosy_cosp)


def quat_from_yaw(yaw: float) -> Tuple[float, float, float, float]:
    half = yaw * 0.5
    return 0.0, 0.0, math.sin(half), math.cos(half)


def read_model_pose(world: str, model: str) -> Tuple[float, float, float, float, float, float, float]:
    topic = f"/world/{world}/dynamic_pose/info"
    proc = subprocess.run(
        ["bash", "-lc", f"timeout 4 gz topic -e -t {topic} | head -n 800"],
        check=False,
        capture_output=True,
        text=True,
        timeout=6,
    )

    in_model = False
    in_position = False
    in_orientation = False
    px = py = pz = 0.0
    qx = qy = qz = 0.0
    qw = 1.0

    for line in proc.stdout.splitlines():
        s = line.strip()
        if s == f'name: "{model}"':
            in_model = True
            continue
        if not in_model:
            continue

        if s == "position {":
            in_position = True
            in_orientation = False
            continue
        if s == "orientation {":
            in_orientation = True
            in_position = False
            continue
        if s == "}":
            if in_orientation:
                return px, py, pz, qx, qy, qz, qw
            in_position = False
            in_orientation = False
            continue

        if in_position and s.startswith("x:"):
            px = float(s.split()[1])
        elif in_position and s.startswith("y:"):
            py = float(s.split()[1])
        elif in_position and s.startswith("z:"):
            pz = float(s.split()[1])
        elif in_orientation and s.startswith("x:"):
            qx = float(s.split()[1])
        elif in_orientation and s.startswith("y:"):
            qy = float(s.split()[1])
        elif in_orientation and s.startswith("z:"):
            qz = float(s.split()[1])
        elif in_orientation and s.startswith("w:"):
            qw = float(s.split()[1])

    raise RuntimeError(f"Could not read model pose for '{model}' on {topic}")


def set_model_pose(
    world: str,
    model: str,
    x: float,
    y: float,
    z: float,
    qx: float,
    qy: float,
    qz: float,
    qw: float,
) -> bool:
    req = (
        f'name: "{model}" '
        f"position: {{x: {x:.6f} y: {y:.6f} z: {z:.6f}}} "
        f"orientation: {{x: {qx:.8f} y: {qy:.8f} z: {qz:.8f} w: {qw:.8f}}}"
    )

    try:
        subprocess.run(
            [
                "gz",
                "service",
                "-s",
                f"/world/{world}/set_pose",
                "--reqtype",
                "gz.msgs.Pose",
                "--reptype",
                "gz.msgs.Boolean",
                "--timeout",
                "1500",
                "--req",
                req,
            ],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=2.0,
        )
        return True
    except subprocess.TimeoutExpired:
        return False


def iter_waypoints() -> Iterable[Tuple[str, float, float]]:
    # Keep the loop well inside `walls` bounds to avoid boundary lock-ups.
    return [
        ("wp_ne", 1.8, 1.2),
        ("wp_nw", -1.8, 1.2),
        ("wp_sw", -1.8, -1.2),
        ("wp_se", 1.8, -1.2),
    ]


def run_motion(world: str, model: str, duration: float, rate: float) -> None:
    px, py, pz, qx, qy, qz, qw = read_model_pose(world, model)
    yaw = yaw_from_quat(qx, qy, qz, qw)

    log(f"submission_drive_ros2: model={model}")
    log(f"submission_drive_ros2: world={world}")
    log(f"submission_drive_ros2: duration={duration:.1f}s rate={rate:.1f}Hz")

    dt = 1.0 / rate if rate > 0 else 0.2
    speed = 0.9
    arrival_radius = 0.2
    waypoints = list(iter_waypoints())
    target_idx = min(
        range(len(waypoints)),
        key=lambda i: (px - waypoints[i][1]) ** 2 + (py - waypoints[i][2]) ** 2,
    )
    target_name, target_x, target_y = waypoints[target_idx]
    log(
        f"submission_drive_ros2: target={target_name} "
        f"x={target_x:.2f} y={target_y:.2f}"
    )

    start = time.monotonic()

    while True:
        now = time.monotonic()
        elapsed = now - start
        if elapsed >= duration:
            break

        dx = target_x - px
        dy = target_y - py
        dist = math.hypot(dx, dy)
        if dist <= arrival_radius:
            target_idx = (target_idx + 1) % len(waypoints)
            target_name, target_x, target_y = waypoints[target_idx]
            log(
                f"submission_drive_ros2: target={target_name} "
                f"x={target_x:.2f} y={target_y:.2f}"
            )
            dx = target_x - px
            dy = target_y - py
            dist = math.hypot(dx, dy)

        if dist > 1e-9:
            yaw = math.atan2(dy, dx)
        step = min(speed * dt, dist)
        px += step * math.cos(yaw)
        py += step * math.sin(yaw)
        qx, qy, qz, qw = quat_from_yaw(yaw)
        if not set_model_pose(world, model, px, py, pz, qx, qy, qz, qw):
            log("submission_drive_ros2: warn=set_pose_timeout")

        sleep_for = dt - (time.monotonic() - now)
        if sleep_for > 0:
            time.sleep(sleep_for)

    qx, qy, qz, qw = quat_from_yaw(yaw)
    set_model_pose(world, model, px, py, pz, qx, qy, qz, qw)
    log("submission_drive_ros2: finished")


def main() -> int:
    parser = argparse.ArgumentParser(description="Deterministic rover motion helper (ROS2/GZ)")
    parser.add_argument("--world", default="rover", help="Gazebo world name")
    parser.add_argument("--model", default="rover_differential_0", help="Gazebo model name")
    parser.add_argument("--duration", type=float, default=90.0, help="Run duration in seconds")
    parser.add_argument("--rate", type=float, default=5.0, help="Control update rate (Hz)")
    args = parser.parse_args()

    try:
        run_motion(args.world, args.model, args.duration, args.rate)
    except Exception as exc:  # pylint: disable=broad-except
        print(f"submission_drive_ros2: error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
