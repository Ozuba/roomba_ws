#!/usr/bin/env python3
"""Classic Roomba behaviour for the rclgd workshop robot: drive straight, and when the bumper
hits or the lidar sees something close ahead, back up a little and turn a random amount.

Runs against the Godot simulator unchanged, which is the point: to ROS it is just a robot.

    python3 bump_and_turn.py
"""

import math
import random

import rclpy
from geometry_msgs.msg import Twist
from rclpy.node import Node
from rclpy.qos import qos_profile_sensor_data
from sensor_msgs.msg import LaserScan
from std_msgs.msg import Bool

FORWARD_SPEED = 0.3  # m/s
TURN_SPEED = 1.8  # rad/s
CLEARANCE = 0.35  # m, obstacle distance ahead that triggers a turn
FRONT_HALF_ANGLE = math.radians(35)


class BumpAndTurn(Node):
    def __init__(self):
        super().__init__('bump_and_turn')
        self.cmd_pub = self.create_publisher(Twist, '/cmd_vel', 10)
        self.create_subscription(Bool, '/bumper', self.on_bumper, 10)
        # The simulated lidar publishes best effort, like real sensors
        self.create_subscription(LaserScan, '/lidar/scan', self.on_scan, qos_profile_sensor_data)
        self.create_timer(0.1, self.step)
        self.state = 'forward'
        self.until = 0.0
        self.turn_dir = 1.0
        self.blocked = False

    def now(self):
        return self.get_clock().now().nanoseconds * 1e-9

    def on_bumper(self, msg):
        if msg.data and self.state == 'forward':
            self.start('backup', 0.6)

    def on_scan(self, msg):
        self.blocked = any(
            msg.range_min < r < CLEARANCE
            for i, r in enumerate(msg.ranges)
            if abs(msg.angle_min + i * msg.angle_increment) < FRONT_HALF_ANGLE
        )

    def start(self, state, duration):
        self.state = state
        self.until = self.now() + duration

    def step(self):
        cmd = Twist()
        if self.state == 'forward':
            if self.blocked:
                self.turn_dir = random.choice((-1.0, 1.0))
                self.start('turn', random.uniform(0.6, 1.8))
            else:
                cmd.linear.x = FORWARD_SPEED
        elif self.state == 'backup':
            cmd.linear.x = -0.15
            if self.now() > self.until:
                self.turn_dir = random.choice((-1.0, 1.0))
                self.start('turn', random.uniform(0.6, 1.8))
        elif self.state == 'turn':
            cmd.angular.z = self.turn_dir * TURN_SPEED
            if self.now() > self.until:
                self.state = 'forward'
        self.cmd_pub.publish(cmd)


def main():
    rclpy.init()
    node = BumpAndTurn()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.cmd_pub.publish(Twist())
        node.destroy_node()
        rclpy.try_shutdown()


if __name__ == '__main__':
    main()
