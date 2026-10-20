Close the loop, and where to go next
====================================

Close the loop from Python
--------------------------

So far you've driven the robot by hand. ``bump_and_turn.py`` is the classic Roomba behaviour:
drive straight, and on a bump or a close lidar return, back off and turn a random amount. It's
an ordinary ``rclpy`` node. To it, the simulator is just a robot, which is the point.

.. code-block:: bash

   python3 ~/rclgd_ws/src/roomba_rclgd/scripts/bump_and_turn.py

.. literalinclude:: ../../src/roomba_rclgd/scripts/bump_and_turn.py
   :language: python
   :caption: scripts/bump_and_turn.py (core of the node)
   :start-at: class BumpAndTurn
   :end-before: def main

Note ``qos_profile_sensor_data`` on the scan subscription: it matches the lidar's best-effort
publisher.

The graph you end up with (``rqt_graph`` shows the same thing). Everything in the Godot box is
one process:

.. mermaid::

   flowchart LR
     subgraph godot["Godot process (roomba_rclgd)"]
       roomba(["/roomba"])
       lidar(["/lidar"])
       imu(["/imu"])
       camera(["/camera"])
       house(["/house"])
     end
     bt(["/bump_and_turn"])
     rviz(["/rviz2"])
     bt -- /cmd_vel --> roomba
     roomba -- /bumper --> bt
     lidar -- /lidar/scan --> bt
     lidar -- /lidar/scan --> rviz
     roomba -- "/odom, /tf, /roomba/marker" --> rviz
     camera -- /camera/image_raw --> rviz
     house -- /house/markers --> rviz

What you used
-------------

.. list-table::
   :header-rows: 1
   :widths: 35 30 35

   * - rclgd
     - rclcpp equivalent
     - Step
   * - ``ROS`` autoload → ``rclgd.init()``
     - ``rclcpp::init()``
     - :doc:`01_tour`
   * - Generated ``RosXxxMsgsYyy`` classes, ``RosMsg.from_type()``
     - generated message headers
     - :doc:`01_tour`
   * - ``RosNode.new()`` + ``init(name, ns)``
     - ``rclcpp::Node``
     - :doc:`02_cmd_vel`
   * - ``create_subscription(topic, type, callable, qos)``
     - ``create_subscription``
     - :doc:`02_cmd_vel`
   * - ``create_publisher(topic, type, qos)`` + ``publish(msg)``
     - ``create_publisher``
     - :doc:`03_odom_tf`
   * - ``now()``
     - ``get_clock()->now()``
     - :doc:`03_odom_tf`
   * - ``create_tf_broadcaster()`` + ``send_transform(t, child, parent, static)``
     - ``tf2_ros::(Static)TransformBroadcaster``
     - :doc:`03_odom_tf`
   * - ``rclgd.godot_to_ros_vector/quat()``
     - (no equivalent: Godot ↔ REP 103 axes)
     - :doc:`03_odom_tf`
   * - rclgd-sensors nodes
     - sensor drivers / Gazebo plugins
     - :doc:`04_sensors`
   * - ``create_timer(period, callable)``
     - ``create_timer``
     - :doc:`05_rviz`
   * - ``RosQoS``
     - ``rclcpp::QoS``
     - :doc:`05_rviz`
   * - ``create_service(name, type, callable)``
     - ``create_service`` (callback on the executor thread!)
     - :doc:`06_services_params`
   * - ``declare_parameter``, ``get_parameter``, ``parameter_changed``
     - parameters + ``add_on_set_parameters_callback``
     - :doc:`06_services_params`

Ideas to keep going
-------------------

**Map the house.** Install ``slam_toolbox`` (``sudo apt install ros-jazzy-slam-toolbox``), run
it in online async mode on ``/lidar/scan``, and drive around: the ``map`` it builds should line
up with the markers. Publish ``odom`` without the static ``map → odom`` first, so SLAM can own
that transform.

**Navigate.** With a map, Nav2 can drive the Roomba through ``/cmd_vel``. The robot is a
standard differential-drive base, which is what Nav2's default controllers expect.

**Act on the world.** Add a ``Clean`` action that drives a spiral and leaves a trail of clean
floor (a decal or a texture you paint into), and publish coverage as an ``OccupancyGrid``.

**Call ROS from Godot.** rclgd has clients too: ``create_client`` and ``create_action_client``,
with ``await``-able calls. Make a Godot UI button that calls ``/roomba/dock``.

**Listen to TF.** ``create_tf_listener()`` and ``lookup_transform("map", "base_link")`` return
a Godot ``Transform3D``. Use it to put a Godot object wherever an external node says the robot
is.

**Custom messages.** Make a ``roomba_interfaces`` package with a ``Status.msg`` (battery, bin
full, brush speed), add it to ``package.xml``, regenerate the types, and publish it. No
rebuilding of rclgd is needed.

**More robots.** Instance a second ``Roomba`` in ``main.tscn``, give its node and sensors a
namespace, and prefix its frames.

Reference
---------

* rclgd documentation: https://rclgd.readthedocs.io (the class reference has every method used
  here)
* rclgd source: https://github.com/Ozuba/rclgd
* Godot documentation: https://docs.godotengine.org/en/stable/
