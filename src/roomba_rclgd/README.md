# roomba_rclgd

The finished rclgd Roomba workshop robot, simulated in Godot and exposed to ROS 2:

| Interface | Type |
|---|---|
| `/cmd_vel` (sub) | `geometry_msgs/Twist` |
| `/odom`, `/tf` (`map → odom → base_link`) | `nav_msgs/Odometry`, TF |
| `/lidar/scan`, `/imu/data`, `/camera/image_raw` | `sensor_msgs` (best effort) |
| `/bumper`, `/roomba/marker`, `/house/markers` | `std_msgs/Bool`, `visualization_msgs` |
| `/roomba/dock`, `/roomba/reset_odometry` | `std_srvs/Trigger`, `std_srvs/Empty` |
| `/roomba/rotate_absolute` | `turtlesim/action/RotateAbsolute` |
| `max_linear_speed`, `max_angular_speed` | parameters on `/roomba` |

```bash
ros2 run roomba_rclgd roomba_rclgd
python3 scripts/bump_and_turn.py
rviz2 -d rviz/roomba.rviz
```
