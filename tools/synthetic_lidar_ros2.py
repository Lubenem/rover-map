#!/usr/bin/env python3
"""
Publish a deterministic synthetic LaserScan for Phase D fallback.
"""

import argparse
import math
from typing import List

import rclpy
from rclpy.node import Node
from rclpy.parameter import Parameter
from rclpy.qos import QoSHistoryPolicy, QoSProfile, QoSReliabilityPolicy
from sensor_msgs.msg import LaserScan


def sensor_qos() -> QoSProfile:
    return QoSProfile(
        reliability=QoSReliabilityPolicy.BEST_EFFORT,
        history=QoSHistoryPolicy.KEEP_LAST,
        depth=10,
    )


class SyntheticLidarNode(Node):
    def __init__(self, output_topic: str, frame_id: str, rate_hz: float, samples: int):
        super().__init__("synthetic_lidar_ros2")
        self.set_parameters(
            [Parameter("use_sim_time", Parameter.Type.BOOL, True)]
        )
        self._pub = self.create_publisher(LaserScan, output_topic, sensor_qos())
        self._frame_id = frame_id
        self._samples = max(60, samples)
        self._tick = 0
        self.create_timer(max(0.02, 1.0 / max(1.0, rate_hz)), self._publish_scan)
        self.get_logger().warning(
            f"Synthetic LiDAR fallback enabled: publishing {output_topic}"
        )

    def _publish_scan(self) -> None:
        msg = LaserScan()
        msg.header.stamp = self.get_clock().now().to_msg()
        msg.header.frame_id = self._frame_id
        msg.angle_min = -math.pi
        msg.angle_max = math.pi
        msg.angle_increment = (msg.angle_max - msg.angle_min) / float(self._samples)
        msg.time_increment = 0.0
        msg.scan_time = 1.0 / 15.0
        msg.range_min = 0.1
        msg.range_max = 50.0

        phase = self._tick * 0.03
        ranges: List[float] = []
        intensities: List[float] = []
        for i in range(self._samples):
            a = msg.angle_min + i * msg.angle_increment
            r = 7.0 + 1.5 * math.sin(2.0 * a + phase) + 0.8 * math.cos(5.0 * a - phase)
            r = max(msg.range_min + 0.05, min(msg.range_max - 0.05, r))
            ranges.append(float(r))
            intensities.append(float(80.0 + 40.0 * math.sin(a + phase)))

        msg.ranges = ranges
        msg.intensities = intensities
        self._pub.publish(msg)
        self._tick += 1


def main() -> int:
    parser = argparse.ArgumentParser(description="ROS2 synthetic LaserScan publisher")
    parser.add_argument("--output-topic", default="/phase_d/fallback_scan")
    parser.add_argument("--frame-id", default="base_link")
    parser.add_argument("--rate", type=float, default=15.0)
    parser.add_argument("--samples", type=int, default=720)
    args = parser.parse_args()

    rclpy.init()
    node = SyntheticLidarNode(args.output_topic, args.frame_id, args.rate, args.samples)
    try:
        rclpy.spin(node)
    finally:
        node.destroy_node()
        rclpy.shutdown()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
