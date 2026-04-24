#!/usr/bin/env python3
"""
Convert LaserScan to PointCloud2.
Default path: /laser/scan -> /points_raw
"""

import argparse
import math
from typing import List, Tuple

import rclpy
from rclpy.node import Node
from rclpy.qos import QoSHistoryPolicy, QoSProfile, QoSReliabilityPolicy
from sensor_msgs.msg import LaserScan, PointCloud2
from sensor_msgs_py import point_cloud2


def sensor_qos() -> QoSProfile:
    return QoSProfile(
        reliability=QoSReliabilityPolicy.BEST_EFFORT,
        history=QoSHistoryPolicy.KEEP_LAST,
        depth=10,
    )


class ScanToCloudNode(Node):
    def __init__(self, input_topic: str, output_topic: str):
        super().__init__("scan_to_cloud_ros2")
        qos = sensor_qos()
        self._pub = self.create_publisher(PointCloud2, output_topic, qos)
        self.create_subscription(LaserScan, input_topic, self._cb, qos)
        self.get_logger().info(f"scan_to_cloud_ros2: {input_topic} -> {output_topic}")

    def _cb(self, msg: LaserScan) -> None:
        points: List[Tuple[float, float, float]] = []
        angle = msg.angle_min

        for r in msg.ranges:
            if math.isfinite(r) and msg.range_min <= r <= msg.range_max:
                x = r * math.cos(angle)
                y = r * math.sin(angle)
                points.append((float(x), float(y), 0.0))
            angle += msg.angle_increment

        cloud = point_cloud2.create_cloud_xyz32(msg.header, points)
        cloud.header.frame_id = msg.header.frame_id
        self._pub.publish(cloud)


def main() -> int:
    parser = argparse.ArgumentParser(description="ROS2 LaserScan -> PointCloud2 converter")
    parser.add_argument("--input-topic", default="/laser/scan")
    parser.add_argument("--output-topic", default="/points_raw")
    args = parser.parse_args()

    rclpy.init()
    node = ScanToCloudNode(args.input_topic, args.output_topic)
    try:
        rclpy.spin(node)
    finally:
        node.destroy_node()
        rclpy.shutdown()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
