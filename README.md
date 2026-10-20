# rclgd workshop: a Roomba in a house

A 90-minute, hands-on workshop on building ROS 2 robot simulators in Godot with
[rclgd](https://github.com/Ozuba/rclgd). You start from a furnished flat and a vacuum robot that
only knows Godot physics, and you connect it to ROS 2 step by step: `/cmd_vel`, odometry and
TF, a lidar, IMU and camera, RViz markers, services, parameters and an action server.

![The finished Roomba in the flat](docs/_static/images/hero_overview.png)

| Path | What it is |
|---|---|
| `src/roomba_rclgd_starter` | Where attendees start: world, robot physics, addons, RViz config, **no ROS code** |
| `src/roomba_rclgd` | The finished result, with every tutorial step applied |
| `docs/` | The tutorial (Sphinx, published on Read the Docs) |
| `docker/`, `.devcontainer/` | The workshop container: Ubuntu 24.04, ROS 2 Jazzy, rclgd |

## Quick start

Inside the container (VS Code: *Dev Containers: Reopen in Container*):

```bash
cd ~/rclgd_ws
colcon build --packages-select roomba_rclgd_starter roomba_rclgd
source install/setup.zsh

ros2 run roomba_rclgd roomba_rclgd                          # the finished robot
python3 src/roomba_rclgd/scripts/bump_and_turn.py           # let it wander
rviz2 -d src/roomba_rclgd/rviz/roomba.rviz                  # and watch it in RViz

ros2 rclgd editor roomba_rclgd_starter                      # start the workshop
```

Then follow the tutorial in `docs/`. The container already has the Sphinx toolchain, so to
build it locally:

```bash
make -C docs html                                           # open docs/_build/html/index.html
```

Outside the container, run `pip install -r docs/requirements.txt` first.
