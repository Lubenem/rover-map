#!/usr/bin/env python3
"""
Deterministic synthetic source for FAST-LIVO2 validation.
Publishes:
  - /points_raw      (sensor_msgs/PointCloud2) at 10 Hz
  - /imu             (sensor_msgs/Imu) at 200 Hz
  - /livox/imu       (sensor_msgs/Imu) at 200 Hz
"""
import math
import rospy
import sensor_msgs.point_cloud2 as pc2
from sensor_msgs.msg import PointCloud2, Imu
from geometry_msgs.msg import Quaternion
from tf.transformations import quaternion_from_euler


class FakeSensorSource:
    def __init__(self):
        self.pc_pub = rospy.Publisher("/points_raw", PointCloud2, queue_size=5)
        self.imu_pub = rospy.Publisher("/imu", Imu, queue_size=50)
        self.livox_imu_pub = rospy.Publisher("/livox/imu", Imu, queue_size=50)
        self.start_t = rospy.Time.now().to_sec()
        self.frame_id = "livox_frame"
        self.landmarks = self._build_landmarks()

        rospy.Timer(rospy.Duration(0.005), self._publish_imu)   # 200 Hz
        rospy.Timer(rospy.Duration(0.1), self._publish_cloud)   # 10 Hz

    def _build_landmarks(self):
        pts = []
        # Two vertical walls + a few pillars for structure.
        for y in [i * 0.25 - 5.0 for i in range(41)]:
            for z in [i * 0.2 - 1.0 for i in range(16)]:
                pts.append((8.0, y, z))
                pts.append((-8.0, y, z))
        for x in [i * 0.25 - 5.0 for i in range(41)]:
            for z in [i * 0.2 - 1.0 for i in range(16)]:
                pts.append((x, 8.0, z))
                pts.append((x, -8.0, z))
        for cx, cy in [(3.0, 2.0), (-2.5, -2.0), (1.0, -3.5)]:
            for a_i in range(48):
                a = 2.0 * math.pi * float(a_i) / 48.0
                for z in [i * 0.2 - 0.5 for i in range(10)]:
                    pts.append((cx + 0.5 * math.cos(a), cy + 0.5 * math.sin(a), z))
        return pts

    def _state(self, t):
        # Smooth planar trajectory + yaw.
        yaw = 0.12 * t
        x = 1.5 * math.cos(0.07 * t)
        y = 1.5 * math.sin(0.07 * t)
        z = 0.2
        return x, y, z, yaw

    def _publish_imu(self, _evt):
        now = rospy.Time.now()
        t = now.to_sec() - self.start_t
        _, _, _, yaw = self._state(t)
        qx, qy, qz, qw = quaternion_from_euler(0.0, 0.0, yaw)

        msg = Imu()
        msg.header.stamp = now
        msg.header.frame_id = self.frame_id
        msg.orientation = Quaternion(x=qx, y=qy, z=qz, w=qw)
        msg.angular_velocity.z = 0.12
        msg.linear_acceleration.z = 9.81
        msg.orientation_covariance[0] = 1e-4
        msg.orientation_covariance[4] = 1e-4
        msg.orientation_covariance[8] = 1e-4
        msg.angular_velocity_covariance[0] = 1e-4
        msg.angular_velocity_covariance[4] = 1e-4
        msg.angular_velocity_covariance[8] = 1e-4
        msg.linear_acceleration_covariance[0] = 1e-3
        msg.linear_acceleration_covariance[4] = 1e-3
        msg.linear_acceleration_covariance[8] = 1e-3

        self.imu_pub.publish(msg)
        self.livox_imu_pub.publish(msg)

    def _publish_cloud(self, _evt):
        now = rospy.Time.now()
        t = now.to_sec() - self.start_t
        px, py, pz, yaw = self._state(t)
        c = math.cos(yaw)
        s = math.sin(yaw)

        points = []
        for wx, wy, wz in self.landmarks:
            dx = wx - px
            dy = wy - py
            dz = wz - pz
            # World -> body (yaw only)
            bx = c * dx + s * dy
            by = -s * dx + c * dy
            bz = dz
            dist = math.sqrt(bx * bx + by * by + bz * bz)
            if 1.0 < dist < 30.0:
                points.append((bx, by, bz))

        header = rospy.Header()
        header.stamp = now
        header.frame_id = self.frame_id
        cloud = pc2.create_cloud_xyz32(header, points)
        self.pc_pub.publish(cloud)


def main():
    rospy.init_node("fake_sensor_source")
    FakeSensorSource()
    rospy.loginfo("fake_sensor_source: publishing /points_raw + /imu + /livox/imu")
    rospy.spin()


if __name__ == "__main__":
    main()
