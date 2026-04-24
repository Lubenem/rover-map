#!/usr/bin/env python3
"""
Subscribe to a ROS2 topic and estimate receive rate.
Output format:
  count=<N> rate=<R> [extra metrics...]
"""

import argparse
import math
import time

from livox_ros_driver2.msg import CustomMsg
import rclpy
from rclpy.node import Node
from rclpy.qos import QoSHistoryPolicy, QoSProfile, QoSReliabilityPolicy
from sensor_msgs.msg import Imu, LaserScan, PointCloud2


MSG_TYPES = {
    "sensor_msgs/msg/Imu": Imu,
    "sensor_msgs/msg/LaserScan": LaserScan,
    "sensor_msgs/msg/PointCloud2": PointCloud2,
    "livox_ros_driver2/msg/CustomMsg": CustomMsg,
}


def sensor_qos() -> QoSProfile:
    return QoSProfile(
        reliability=QoSReliabilityPolicy.BEST_EFFORT,
        history=QoSHistoryPolicy.KEEP_LAST,
        depth=30,
    )


class ProbeNode(Node):
    def __init__(self, topic: str, msg_type, metric: str, max_samples: int):
        super().__init__("ros2_topic_probe")
        self.metric = metric
        self.max_samples = max_samples
        self.times = []
        self.max_width = 0
        self.max_point_num = 0
        self._n = 0
        self._mean = 0.0
        self._m2 = 0.0
        self.create_subscription(msg_type, topic, self._cb, sensor_qos())

    def _accumulate(self, value: float) -> None:
        self._n += 1
        delta = value - self._mean
        self._mean += delta / self._n
        delta2 = value - self._mean
        self._m2 += delta * delta2

    def _cb(self, msg) -> None:
        self.times.append(time.monotonic())
        if self.metric == "pointcloud_width" and isinstance(msg, PointCloud2):
            width = int(msg.width)
            if width > self.max_width:
                self.max_width = width
            return

        if self.metric in ("livox_point_num", "livox_reflectivity_variance") and isinstance(msg, CustomMsg):
            point_num = int(msg.point_num)
            if point_num > self.max_point_num:
                self.max_point_num = point_num

            if self.metric == "livox_reflectivity_variance":
                remaining = self.max_samples - self._n
                if remaining <= 0:
                    return
                for p in msg.points[:remaining]:
                    self._accumulate(float(p.reflectivity))

    def reflectivity_variance(self) -> float:
        if self._n < 2:
            return 0.0
        return self._m2 / (self._n - 1)


def main() -> int:
    parser = argparse.ArgumentParser(description="Probe ROS2 topic rate")
    parser.add_argument("--topic", required=True)
    parser.add_argument("--msg-type", required=True, choices=MSG_TYPES.keys())
    parser.add_argument(
        "--metric",
        default="none",
        choices=("none", "pointcloud_width", "livox_point_num", "livox_reflectivity_variance"),
    )
    parser.add_argument("--timeout", type=float, default=20.0)
    parser.add_argument("--min-msgs", type=int, default=3)
    parser.add_argument("--max-samples", type=int, default=30000)
    args = parser.parse_args()

    rclpy.init()
    node = ProbeNode(args.topic, MSG_TYPES[args.msg_type], args.metric, args.max_samples)
    deadline = time.monotonic() + args.timeout

    try:
        while time.monotonic() < deadline and len(node.times) < args.min_msgs:
            rclpy.spin_once(node, timeout_sec=0.2)
    finally:
        times = list(node.times)
        node.destroy_node()
        rclpy.shutdown()

    count = len(times)
    rate = 0.0
    if count >= 2:
        span = times[-1] - times[0]
        if span > 0:
            rate = (count - 1) / span

    extras = []
    if args.metric == "pointcloud_width":
        extras.append(f"width_max={node.max_width}")
    elif args.metric == "livox_point_num":
        extras.append(f"point_num_max={node.max_point_num}")
    elif args.metric == "livox_reflectivity_variance":
        variance = node.reflectivity_variance()
        if math.isnan(variance):
            variance = 0.0
        extras.append(f"point_num_max={node.max_point_num}")
        extras.append(f"reflectivity_variance={variance:.6f}")

    suffix = ""
    if extras:
        suffix = " " + " ".join(extras)
    print(f"count={count} rate={rate:.6f}{suffix}")
    if count < args.min_msgs:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
