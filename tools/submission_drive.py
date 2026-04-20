#!/usr/bin/env python3
"""
Deterministic rover motion helper for submission capture.
Moves rover in a repeatable route by updating Gazebo model state.
"""
import argparse
import math
import os
import time

import rospy
from gazebo_msgs.msg import ModelState
from gazebo_msgs.srv import GetModelState, SetModelState
from tf.transformations import euler_from_quaternion, quaternion_from_euler


def setup_env_defaults():
    os.environ.setdefault("ROS_MASTER_URI", "http://127.0.0.1:12711")
    os.environ.setdefault("GAZEBO_MASTER_URI", "http://127.0.0.1:12745")


def yaw_from_quat(q):
    return euler_from_quaternion([q.x, q.y, q.z, q.w])[2]


def run_route(model_name: str, duration: float, rate_hz: float) -> None:
    rospy.wait_for_service("/gazebo/get_model_state", timeout=20.0)
    rospy.wait_for_service("/gazebo/set_model_state", timeout=20.0)
    get_state = rospy.ServiceProxy("/gazebo/get_model_state", GetModelState)
    set_state = rospy.ServiceProxy("/gazebo/set_model_state", SetModelState)

    state = get_state(model_name, "")
    if not state.success:
        raise RuntimeError(f"Failed to get state for model '{model_name}'")

    x = state.pose.position.x
    y = state.pose.position.y
    z = state.pose.position.z
    yaw = yaw_from_quat(state.pose.orientation)

    phases = [
        ("forward_1", 18.0, 0.9, 0.0),
        ("left_turn_1", 5.0, 0.0, 0.45),
        ("forward_2", 15.0, 0.8, 0.0),
        ("right_turn_1", 5.0, 0.0, -0.45),
        ("forward_3", 12.0, 0.8, 0.0),
        ("left_turn_2", 5.0, 0.0, 0.45),
    ]

    rospy.loginfo("submission_drive: started")
    rospy.loginfo("submission_drive: model=%s duration=%.1fs", model_name, duration)
    start = time.time()
    dt = 1.0 / rate_hz
    phase_idx = 0
    phase_start = start

    while not rospy.is_shutdown():
        now = time.time()
        elapsed = now - start
        if elapsed >= duration:
            break

        phase_name, phase_len, v, w = phases[phase_idx]
        phase_elapsed = now - phase_start
        if phase_elapsed >= phase_len:
            phase_idx = (phase_idx + 1) % len(phases)
            phase_start = now
            phase_name, phase_len, v, w = phases[phase_idx]
            rospy.loginfo("submission_drive: phase=%s t=%.1fs", phase_name, elapsed)

        yaw += w * dt
        x += v * math.cos(yaw) * dt
        y += v * math.sin(yaw) * dt
        qx, qy, qz, qw = quaternion_from_euler(0.0, 0.0, yaw)

        msg = ModelState()
        msg.model_name = model_name
        msg.pose.position.x = x
        msg.pose.position.y = y
        msg.pose.position.z = z
        msg.pose.orientation.x = qx
        msg.pose.orientation.y = qy
        msg.pose.orientation.z = qz
        msg.pose.orientation.w = qw
        msg.twist.linear.x = v
        msg.twist.angular.z = w
        msg.reference_frame = "world"
        set_state(msg)

        rospy.sleep(dt)

    msg = ModelState()
    msg.model_name = model_name
    msg.pose.position.x = x
    msg.pose.position.y = y
    msg.pose.position.z = z
    qx, qy, qz, qw = quaternion_from_euler(0.0, 0.0, yaw)
    msg.pose.orientation.x = qx
    msg.pose.orientation.y = qy
    msg.pose.orientation.z = qz
    msg.pose.orientation.w = qw
    msg.twist.linear.x = 0.0
    msg.twist.angular.z = 0.0
    msg.reference_frame = "world"
    set_state(msg)
    rospy.loginfo("submission_drive: finished at t=%.1fs", time.time() - start)


def main():
    parser = argparse.ArgumentParser(description="Deterministic rover motion helper")
    parser.add_argument("--model", default="rover", help="Gazebo model name")
    parser.add_argument("--duration", type=float, default=90.0, help="Run duration in seconds")
    parser.add_argument("--rate", type=float, default=10.0, help="Control loop rate (Hz)")
    args = parser.parse_args()

    setup_env_defaults()
    rospy.init_node("submission_drive")
    run_route(args.model, args.duration, args.rate)


if __name__ == "__main__":
    main()
