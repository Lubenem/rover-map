#!/usr/bin/env python3
"""
Convert PointCloud2 (/points_raw) to livox_ros_driver/CustomMsg (/livox/lidar)
so FAST-LIVO2 can consume simulated lidar data.
"""
import rospy
import struct
import sensor_msgs.point_cloud2 as pc2
from sensor_msgs.msg import PointCloud2
from livox_ros_driver.msg import CustomMsg, CustomPoint


class PointsToLivox:
    def __init__(self):
        self.pub = rospy.Publisher("/livox/lidar", CustomMsg, queue_size=2)
        rospy.Subscriber("/points_raw", PointCloud2, self.cb, queue_size=1)

    def cb(self, msg: PointCloud2):
        points = pc2.read_points(msg, field_names=("x", "y", "z"), skip_nans=True)
        livox_msg = CustomMsg()
        livox_msg.header = msg.header
        livox_msg.timebase = msg.header.stamp.to_nsec()
        livox_msg.lidar_id = 0
        livox_msg.point_num = 0
        livox_msg.rsvd = [0, 0, 0]

        # Build CustomPoint list
        pts = []
        offset = 0
        for x, y, z in points:
            p = CustomPoint()
            p.offset_time = offset  # simple incremental offset (ns) per point
            p.x, p.y, p.z = float(x), float(y), float(z)
            p.reflectivity = 0
            p.tag = 0
            p.line = 0
            pts.append(p)
            offset += 1000  # 1 microsecond step; arbitrary but monotonic

        livox_msg.points = pts
        livox_msg.point_num = len(pts)
        self.pub.publish(livox_msg)


def main():
    rospy.init_node("points_to_livox")
    PointsToLivox()
    rospy.loginfo("points_to_livox: publishing /livox/lidar from /points_raw")
    rospy.spin()


if __name__ == "__main__":
    main()
