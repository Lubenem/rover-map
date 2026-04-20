#!/usr/bin/env python3
"""
Convert /laser/scan -> /points_raw (PointCloud2) using laser_geometry.
Keeps frame from incoming scan; requires TF to be available (we already publish static base_link->rplidar_link).
"""
import rospy
import laser_geometry.laser_geometry as lg
from sensor_msgs.msg import LaserScan, PointCloud2


class ScanToCloud:
    def __init__(self):
        self.projector = lg.LaserProjection()
        self.pub = rospy.Publisher("/points_raw", PointCloud2, queue_size=10)
        rospy.Subscriber("/laser/scan", LaserScan, self.cb, queue_size=10)

    def cb(self, msg: LaserScan):
        cloud = self.projector.projectLaser(msg)
        # keep same frame_id; downstream can transform if needed
        cloud.header.frame_id = msg.header.frame_id
        self.pub.publish(cloud)


def main():
    rospy.init_node("scan_to_cloud")
    ScanToCloud()
    rospy.loginfo("scan_to_cloud: publishing /points_raw from /laser/scan")
    rospy.spin()


if __name__ == "__main__":
    main()
