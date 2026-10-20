Odometry and TF
===============

*15 minutes.* **You add:** a ``nav_msgs/Odometry`` publisher and a TF broadcaster that
publishes ``map → odom`` (static) and ``odom → base_link`` (every physics step).

The frames
----------

.. mermaid::

   flowchart LR
     map -- "static: where the robot started" --> odom
     odom -- "dynamic: /odom, every physics step" --> base_link
     base_link -- "static, step 4" --> lidar
     base_link -- "static, step 4" --> imu
     base_link -- "static, step 4" --> camera

``map``
   The house itself. Its origin is the Godot world origin, at the flat's north-west corner.

``odom``
   Where the robot was when odometry started. It's fixed in the map, so ``map → odom`` is a
   static transform.

``base_link``
   The robot's own frame, at the centre of its footprint on the floor, with x forward.

The odometry here comes from the simulator's ground truth, so it never drifts. If you want to
practise localization, adding noise is a nice exercise for later.

Add the publisher and the broadcaster
-------------------------------------

New members, next to the step 2 ones:

.. code-block:: gdscript

   # Step 3: odometry and TF
   var _odom_pub: RosPublisher
   var _tf: RosTfBroadcaster
   var _odom_msg := RosNavMsgsOdometry.new()
   var _odom_origin: Transform3D # Pose the odom frame was started at (global)

In ``_ready()``, after creating the subscription:

.. code-block:: gdscript

   	_setup_odometry()

And the setup:

.. code-block:: gdscript

   func _setup_odometry() -> void:
   	_odom_pub = _node.create_publisher("/odom", "nav_msgs/msg/Odometry")
   	_tf = _node.create_tf_broadcaster()
   	_odom_msg.header.frame_id = "odom"
   	_odom_msg.child_frame_id = "base_link"
   	_reset_odometry()


   ## Starts the odom frame at the current pose. map -> odom is static: the house is the map.
   func _reset_odometry() -> void:
   	_odom_origin = global_transform
   	_tf.send_transform(_odom_origin, "odom", "map", true)

Publish every physics step
--------------------------

``_physics_process()`` runs once per physics step (60 Hz). Add one line to the one you wrote in
step 2:

.. code-block:: gdscript

   func _physics_process(_delta: float) -> void:
   	if _now_s() - _last_cmd_time > cmd_vel_timeout:
   		stop()
   	_publish_odometry()

And the publisher itself:

.. code-block:: gdscript

   func _publish_odometry() -> void:
   	# Pose of the robot in the odom frame, still in Godot axes
   	var pose := _odom_origin.affine_inverse() * global_transform

   	_odom_msg.header.stamp = _node.now()
   	var p := rclgd.godot_to_ros_vector(pose.origin)
   	_odom_msg.pose.pose.position.x = p.x
   	_odom_msg.pose.pose.position.y = p.y
   	_odom_msg.pose.pose.position.z = p.z
   	var q := rclgd.godot_to_ros_quat(pose.basis.get_rotation_quaternion())
   	_odom_msg.pose.pose.orientation.x = q.x
   	_odom_msg.pose.pose.orientation.y = q.y
   	_odom_msg.pose.pose.orientation.z = q.z
   	_odom_msg.pose.pose.orientation.w = q.w
   	# Twist is expressed in the robot's own frame (child_frame_id)
   	var v := rclgd.godot_to_ros_vector(global_basis.inverse() * linear_velocity)
   	_odom_msg.twist.twist.linear.x = v.x
   	_odom_msg.twist.twist.linear.y = v.y
   	_odom_msg.twist.twist.angular.z = angular_velocity.y
   	_odom_pub.publish(_odom_msg)

   	# The same pose as TF; the broadcaster converts the Godot transform to ROS axes itself
   	_tf.send_transform(pose, "base_link", "odom")

How it works
------------

**Godot does the geometry.** ``Transform3D`` is a full rigid transform (basis plus origin), so
"the robot relative to where it started" is a single expression:
``_odom_origin.affine_inverse() * global_transform``. You stay in Godot types for as long as
possible and convert at the edge.

**Converting at the edge.** ``rclgd.godot_to_ros_vector()`` maps (−Z, −X, +Y) to (X, Y, Z), and
``godot_to_ros_quat()`` does the same for rotations. ``RosTfBroadcaster.send_transform()``
takes a Godot ``Transform3D`` and converts it for you. Its arguments are
``(transform, child_frame, parent_frame, is_static)``. Static transforms go to ``/tf_static``
with transient-local durability, exactly like a ``StaticTransformBroadcaster``.

**Yaw is free.** Godot's rotation about +Y (up) and ROS's rotation about +Z (up) are the same
angle with the same sign, so the twist's ``angular.z`` is just ``angular_velocity.y``.

**Stamps.** ``_node.now()`` returns a ``builtin_interfaces/Time`` from the node's clock. It
honours ``use_sim_time`` if you ever drive the simulation from ``/clock``.

**Reusing messages.** ``_odom_msg`` is created once and refilled every step. Nested fields are
references, so ``_odom_msg.pose.pose.position.x = p.x`` writes straight into the message.
Arrays are the one exception: they're copies, so assign a whole array at once (you'll see this
in :doc:`05_rviz`).

Check it
--------

.. code-block:: console

   $ ros2 topic hz /odom
   average rate: 60.002

   $ ros2 run tf2_ros tf2_echo map base_link
   At time 1792432218.64
   - Translation: [-3.050, -0.390, 0.000]
   - Rotation: in Quaternion [0.000, 0.000, -0.707, 0.707]

In the map frame the robot starts at about (−3.05, −0.39), facing −Y (yaw −90°). That's
Godot's (0.39, 0, 3.05) facing +X, through the axis table in :doc:`01_tour`. Drive forward with
teleop and the ``odom → base_link`` x grows: forward is +X in ``base_link``, whichever way the
robot faces in the house.

.. code-block:: bash

   ros2 run tf2_ros tf2_echo odom base_link
   ros2 run tf2_tools view_frames     # writes frames_<date>.pdf with the tree
