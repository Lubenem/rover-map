#!/usr/bin/env python3
"""
Convert PointCloud2 (/points_raw) to livox_ros_driver2/CustomMsg (/livox/lidar).

Reflectivity is generated from range to avoid flat grayscale output in RViz.
"""

import argparse
import math

from livox_ros_driver2.msg import CustomMsg, CustomPoint
import rclpy
from rclpy.node import Node
from rclpy.qos import QoSHistoryPolicy, QoSProfile, QoSReliabilityPolicy
from sensor_msgs.msg import PointCloud2
from sensor_msgs_py import point_cloud2


def sub_qos() -> QoSProfile:
    return QoSProfile(
        reliability=QoSReliabilityPolicy.BEST_EFFORT,
        history=QoSHistoryPolicy.KEEP_LAST,
        depth=10,
    )


def pub_qos() -> QoSProfile:
    return QoSProfile(
        reliability=QoSReliabilityPolicy.RELIABLE,
        history=QoSHistoryPolicy.KEEP_LAST,
        depth=30,
    )


class PointsToLivoxNode(Node):
    def __init__(self, input_topic: str, output_topic: str):
        super().__init__("points_to_livox_ros2")
        self._pub = self.create_publisher(CustomMsg, output_topic, pub_qos())
        self.create_subscription(PointCloud2, input_topic, self._cb, sub_qos())
        self.get_logger().info(f"points_to_livox_ros2: {input_topic} -> {output_topic}")

    def _cb(self, msg: PointCloud2) -> None:
        points = point_cloud2.read_points(msg, field_names=("x", "y", "z"), skip_nans=True)

        out = CustomMsg()
        out.header = msg.header
        out.timebase = int(msg.header.stamp.sec) * 1_000_000_000 + int(msg.header.stamp.nanosec)
        out.lidar_id = 0
        out.rsvd = [0, 0, 0]

        converted = []
        offset_us = 0
        near_m = 0.15
        far_m = 45.0
        span = far_m - near_m

        for x, y, z in points:
            distance = math.sqrt(float(x) * float(x) + float(y) * float(y) + float(z) * float(z))
            norm = (distance - near_m) / span
            if norm < 0.0:
                norm = 0.0
            elif norm > 1.0:
                norm = 1.0
            reflectivity = int(round((1.0 - norm) * 255.0))

            p = CustomPoint()
            p.offset_time = offset_us
            p.x = float(x)
            p.y = float(y)
            p.z = float(z)
            p.reflectivity = reflectivity
            p.tag = 0x10
            p.line = 0
            converted.append(p)
            offset_us += 1000

        out.points = converted
        out.point_num = len(converted)
        self._pub.publish(out)


def main() -> int:
    parser = argparse.ArgumentParser(description="ROS2 /points_raw -> /livox/lidar converter")
    parser.add_argument("--input-topic", default="/points_raw")
    parser.add_argument("--output-topic", default="/livox/lidar")
    args = parser.parse_args()

    rclpy.init()
    node = PointsToLivoxNode(args.input_topic, args.output_topic)
    try:
        rclpy.spin(node)
    finally:
        node.destroy_node()
        rclpy.shutdown()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
