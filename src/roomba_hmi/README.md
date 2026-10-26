# roomba_hmi

The finished extra section of the rclgd workshop: a simple control panel for the Roomba, laid
out in the Godot editor and talking to the robot over ROS 2 with rclgd.

| Widget | ROS 2 interface |
|---|---|
| Camera view | `/camera/image_raw` (sub, best effort, `rgba8`) |
| Speed line (red while bumped) | `/odom`, `/bumper` (sub) |
| ▲ ◀ ▶ ▼ (hold to drive), speed slider | `/cmd_vel` (pub, only while an arrow is held) |
| *Dock* button | `/roomba/dock` (service client) |

```bash
ros2 run roomba_rclgd roomba_rclgd   # the robot
ros2 run roomba_hmi roomba_hmi       # the HMI
```

There is no starter for this one: the tutorial builds it from `ros2 rclgd create`.
