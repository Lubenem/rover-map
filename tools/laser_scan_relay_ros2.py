#!/usr/bin/env python3
"""
Relay LaserScan from discovered Gazebo topic to a stable /laser/scan topic.
"""

import argparse

import rclpy
from rclpy.node import Node
from rclpy.qos import QoSHistoryPolicy, QoSProfile, QoSReliabilityPolicy
from sensor_msgs.msg import LaserScan


def sensor_qos() -> QoSProfile:
    return QoSProfile(
        reliability=QoSReliabilityPolicy.BEST_EFFORT,
        history=QoSHistoryPolicy.KEEP_LAST,
        depth=20,
    )


class LaserScanRelayNode(Node):
    def __init__(self, input_topic: str, output_topic: str):
        super().__init__("laser_scan_relay_ros2")
        qos = sensor_qos()
        self._pub = self.create_publisher(LaserScan, output_topic, qos)
        self.create_subscription(LaserScan, input_topic, self._cb, qos)
        self.get_logger().info(f"laser_scan_relay_ros2: {input_topic} -> {output_topic}")

    def _cb(self, msg: LaserScan) -> None:
        self._pub.publish(msg)


def main() -> int:
    parser = argparse.ArgumentParser(description="ROS2 LaserScan relay")
    parser.add_argument("--input-topic", required=True)
    parser.add_argument("--output-topic", default="/laser/scan")
    args = parser.parse_args()

    rclpy.init()
    node = LaserScanRelayNode(args.input_topic, args.output_topic)
    try:
        rclpy.spin(node)
    finally:
        node.destroy_node()
        rclpy.shutdown()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
