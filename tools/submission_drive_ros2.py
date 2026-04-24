#!/usr/bin/env python3
"""
Phase D scaffold for deterministic rover motion in ROS2 stack.
Real motion control (Gazebo Harmonic + PX4 rover) will be added in a later phase.
"""

import argparse


def main() -> int:
    parser = argparse.ArgumentParser(description="ROS2 rover drive helper (Phase D scaffold)")
    parser.add_argument("--model", default="rover", help="Gazebo model name")
    parser.add_argument("--duration", type=float, default=90.0, help="Run duration in seconds")
    parser.add_argument("--rate", type=float, default=10.0, help="Control loop rate (Hz)")
    args = parser.parse_args()

    print("ROS2 drive scaffold is ready (Phase D).")
    print(f"Requested model={args.model} duration={args.duration} rate={args.rate}")
    print("Note: motion implementation will be added in later phases.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
