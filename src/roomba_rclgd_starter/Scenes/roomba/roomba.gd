class_name Roomba
extends RigidBody3D
## A small differential-drive vacuum robot, simulated with plain Godot physics.
##
## Call drive(linear, angular) and the body follows those speeds every physics tick, sliding
## along whatever it touches. The front bumper reports contacts through bumper_changed.
## Nothing here knows about ROS yet: that is what you add during the workshop.

## Emitted when the front bumper is pressed or released
signal bumper_changed(pressed: bool)

@export_group("Drive")
## Forward speed limit (m/s)
@export var max_linear_speed: float = 0.5
## Turn rate limit (rad/s)
@export var max_angular_speed: float = 2.5
## How fast the wheels reach the commanded speeds (m/s² and rad/s²)
@export var linear_acceleration: float = 1.5
@export var angular_acceleration: float = 8.0

## Current wheel speeds after the acceleration ramp (m/s, rad/s; positive = forward, left)
var linear_speed: float = 0.0
var angular_speed: float = 0.0
## True while something is pressing the front half of the bumper
var bumper_pressed: bool = false

var _target_linear: float = 0.0
var _target_angular: float = 0.0
var _teleport_target = null # Transform3D waiting to be applied in the next physics step

@onready var _led: MeshInstance3D = $Visuals/Led
@onready var _side_brush: Node3D = $Visuals/SideBrush

@export_group("ROS 2")
## Stop when no /cmd_vel arrives for this long (s), like most real robot bases
@export var cmd_vel_timeout: float = 0.5
# --- ROS 2 ---
var _node: RosNode
# Step 2: velocity commands
var _cmd_vel_sub: RosSubscriber
var _last_cmd_time: float = -INF
# Step 3: odometry and TF
var _odom_pub: RosPublisher
var _tf: RosTfBroadcaster
var _odom_msg := RosNavMsgsOdometry.new()
var _odom_origin: Transform3D # Pose the odom frame was started at (global)


func _ready() -> void:
	# Step 2: one RosNode per robot. The ROS autoload already initialized rclgd.
	_node = RosNode.new()
	_node.init("roomba")
	_cmd_vel_sub = _node.create_subscription("/cmd_vel", "geometry_msgs/msg/Twist", _on_cmd_vel)
	_setup_odometry()

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


## Topic callbacks run on Godot's main thread, so the scene can be touched directly
func _on_cmd_vel(msg: RosMsg) -> void:
	_last_cmd_time = _now_s()
	drive(msg.linear.x, msg.angular.z)


func _now_s() -> float:
	return Time.get_ticks_msec() / 1000.0

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
func _physics_process(_delta: float) -> void:
	if _now_s() - _last_cmd_time > cmd_vel_timeout:
			stop()
	_publish_odometry()

## Sets the commanded speeds: linear in m/s (forward), angular in rad/s (counterclockwise
## seen from above). Both are clamped to the limits.
func drive(linear: float, angular: float) -> void:
	_target_linear = clampf(linear, -max_linear_speed, max_linear_speed)
	_target_angular = clampf(angular, -max_angular_speed, max_angular_speed)


func stop() -> void:
	drive(0.0, 0.0)


## Moves the robot to a global transform (e.g. the dock), stopped
func teleport(target: Transform3D) -> void:
	stop()
	_teleport_target = target


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _teleport_target != null:
		state.transform = _teleport_target
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		linear_speed = 0.0
		angular_speed = 0.0
		_teleport_target = null
		return

	# Differential drive: the wheels set the velocity along the robot's heading and the yaw
	# rate. Gravity keeps acting on the vertical component.
	linear_speed = move_toward(linear_speed, _target_linear, linear_acceleration * state.step)
	angular_speed = move_toward(angular_speed, _target_angular, angular_acceleration * state.step)
	var forward := -state.transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	state.linear_velocity = forward * linear_speed + Vector3.UP * state.linear_velocity.y
	state.angular_velocity = Vector3.UP * angular_speed

	_update_bumper(state)


## The bumper covers the front half of the robot. Contacts with the floor (normals pointing
## up) don't count.
func _update_bumper(state: PhysicsDirectBodyState3D) -> void:
	var pressed := false
	for i in state.get_contact_count():
		if absf(state.get_contact_local_normal(i).y) > 0.5:
			continue
		var contact := state.transform.affine_inverse() * state.get_contact_local_position(i)
		if contact.z < 0.0: # Forward is -Z
			pressed = true
			break
	if pressed != bumper_pressed:
		bumper_pressed = pressed
		bumper_changed.emit(pressed)


func _process(delta: float) -> void:
	# Cosmetics: spin the side brush while moving, LED shows the state
	var moving := absf(linear_speed) > 0.01 or absf(angular_speed) > 0.01
	if moving:
		_side_brush.rotate_y(-18.0 * delta)
	var led_mat := _led.material_override as StandardMaterial3D
	var color := Color(1.0, 0.2, 0.15) if bumper_pressed else (Color(0.2, 0.6, 1.0) if moving else Color(0.2, 1.0, 0.45))
	led_mat.albedo_color = color
	led_mat.emission = color
