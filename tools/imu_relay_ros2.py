#!/usr/bin/env python3
"""
ROS2 IMU relay:
/imu -> /livox/imu
"""

import argparse

import rclpy
from rclpy.node import Node
from rclpy.qos import QoSHistoryPolicy, QoSProfile, QoSReliabilityPolicy
from sensor_msgs.msg import Imu


def sub_qos() -> QoSProfile:
    return QoSProfile(
        reliability=QoSReliabilityPolicy.BEST_EFFORT,
        history=QoSHistoryPolicy.KEEP_LAST,
        depth=30,
    )


def pub_qos() -> QoSProfile:
    return QoSProfile(
        reliability=QoSReliabilityPolicy.RELIABLE,
        history=QoSHistoryPolicy.KEEP_LAST,
        depth=50,
    )


class ImuRelayNode(Node):
    def __init__(self, input_topic: str, output_topic: str):
        super().__init__("imu_relay_ros2")
        self._pub = self.create_publisher(Imu, output_topic, pub_qos())
        self.create_subscription(Imu, input_topic, self._cb, sub_qos())
        self.get_logger().info(f"imu_relay_ros2: {input_topic} -> {output_topic}")

    def _cb(self, msg: Imu) -> None:
        self._pub.publish(msg)


def main() -> int:
    parser = argparse.ArgumentParser(description="ROS2 IMU relay")
    parser.add_argument("--input-topic", default="/imu")
    parser.add_argument("--output-topic", default="/livox/imu")
    args = parser.parse_args()

    rclpy.init()
    node = ImuRelayNode(args.input_topic, args.output_topic)
    try:
        rclpy.spin(node)
    finally:
        node.destroy_node()
        rclpy.shutdown()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
