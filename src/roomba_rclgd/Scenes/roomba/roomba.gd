class_name Roomba
extends RigidBody3D
## A small differential-drive vacuum robot, simulated with plain Godot physics and exposed to
## ROS 2 through rclgd.
##
## The physics part (drive(), the bumper, teleport()) is the same as in the starter. Everything
## under the "ROS 2" sections below was added step by step in the workshop tutorial.

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

@export_group("ROS 2")
## Stop when no /cmd_vel arrives for this long (s), like most real robot bases
@export var cmd_vel_timeout: float = 0.5
## Where the ~/dock service sends the robot
@export var dock: Node3D

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
# Step 5: bumper and RViz marker
var _bumper_pub: RosPublisher
var _marker_pub: RosPublisher
var _status_timer: RosTimer
var _bumper_msg := RosStdMsgsBool.new()
var _marker_msg := RosVisualizationMsgsMarker.new()
# Step 6: services
var _dock_srv: RosService
var _reset_odom_srv: RosService
var _dock_pose: Transform3D # Read on the main thread; service callbacks must not touch nodes
# Step 7: action
var _rotate_server: RosActionServer
var _rotate_goal: RosServerGoalHandle # Goal steering the robot (null = none); /cmd_vel is ignored meanwhile


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


func _ready() -> void:
	# Step 2: one RosNode per robot. The ROS autoload already initialized rclgd.
	_node = RosNode.new()
	_node.init("roomba")
	_cmd_vel_sub = _node.create_subscription("/cmd_vel", "geometry_msgs/msg/Twist", _on_cmd_vel)

	_setup_odometry()
	_setup_status()
	_setup_services()
	_setup_parameters()
	_setup_actions()


# --- Step 2: /cmd_vel --------------------------------------------------------------------------

## Topic callbacks run on Godot's main thread, so the scene can be touched directly
func _on_cmd_vel(msg: RosMsg) -> void:
	if _rotate_goal:
		return
	_last_cmd_time = _now_s()
	drive(msg.linear.x, msg.angular.z)


func _now_s() -> float:
	return Time.get_ticks_msec() / 1000.0


# --- Step 3: odometry and TF ---------------------------------------------------------------------

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


func _physics_process(_delta: float) -> void:
	if not _rotate_goal and _now_s() - _last_cmd_time > cmd_vel_timeout:
		stop()
	_publish_odometry()


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


## Heading in the odom frame (rad, counterclockwise). Godot's yaw about +Y is ROS's yaw about +Z.
func _odom_yaw() -> float:
	return (_odom_origin.affine_inverse() * global_transform).basis.get_euler().y


# --- Step 5: bumper and RViz marker ----------------------------------------------------------------

func _setup_status() -> void:
	_bumper_pub = _node.create_publisher("/bumper", "std_msgs/msg/Bool")
	_marker_pub = _node.create_publisher("~/marker", "visualization_msgs/msg/Marker")

	_marker_msg.header.frame_id = "base_link"
	_marker_msg.ns = "roomba"
	_marker_msg.type = 3 # CYLINDER
	_marker_msg.pose.position.z = 0.045
	_marker_msg.pose.orientation.w = 1.0
	_marker_msg.scale.x = 0.34
	_marker_msg.scale.y = 0.34
	_marker_msg.scale.z = 0.07
	_marker_msg.color.a = 1.0

	# Publish on every bumper change (a Godot signal) and at 10 Hz (a ROS timer)
	bumper_changed.connect(func(_pressed: bool) -> void: _publish_status())
	_status_timer = _node.create_timer(0.1, _publish_status)


func _publish_status() -> void:
	_bumper_msg.data = bumper_pressed
	_bumper_pub.publish(_bumper_msg)

	_marker_msg.header.stamp = _node.now()
	var color := Color(0.9, 0.2, 0.15) if bumper_pressed else Color(0.25, 0.27, 0.3)
	_marker_msg.color.r = color.r
	_marker_msg.color.g = color.g
	_marker_msg.color.b = color.b
	_marker_pub.publish(_marker_msg)


# --- Step 6: services ------------------------------------------------------------------------------

func _setup_services() -> void:
	_dock_pose = dock.global_transform if dock else global_transform
	_dock_srv = _node.create_service("~/dock", "std_srvs/srv/Trigger", _on_dock)
	_reset_odom_srv = _node.create_service("~/reset_odometry", "std_srvs/srv/Empty", _on_reset_odometry)


## Service callbacks run on the ROS executor thread: fill the response here, but defer any
## change to the scene to the main thread.
func _on_dock(_req: RosMsg, res: RosMsg) -> void:
	teleport.call_deferred(_dock_pose)
	res.success = true
	res.message = "Back on the dock"


func _on_reset_odometry(_req: RosMsg, _res: RosMsg) -> void:
	_reset_odometry.call_deferred()


# --- Step 6: parameters ----------------------------------------------------------------------------

func _setup_parameters() -> void:
	# The exported values are the defaults; -p overrides (command line or the ros/parameters
	# project settings) win, so read them back after declaring.
	_node.declare_parameter("max_linear_speed", max_linear_speed)
	_node.declare_parameter("max_angular_speed", max_angular_speed)
	max_linear_speed = _node.get_parameter("max_linear_speed")
	max_angular_speed = _node.get_parameter("max_angular_speed")
	_node.parameter_changed.connect(_on_parameter_changed)


## Called for every `ros2 param set` on this node
func _on_parameter_changed(param_name: String, value: Variant) -> void:
	match param_name:
		"max_linear_speed":
			max_linear_speed = value
		"max_angular_speed":
			max_angular_speed = value


# --- Step 7: action ------------------------------------------------------------------------------

func _setup_actions() -> void:
	_rotate_server = _node.create_action_server("~/rotate_absolute",
			"turtlesim/action/RotateAbsolute", _execute_rotate)


## Turns in place to an absolute heading in the odom frame. The execute callback runs on the
## main thread, so it advances one physics frame at a time with await instead of blocking.
func _execute_rotate(goal: RosServerGoalHandle) -> void:
	_rotate_goal = goal # A newer goal takes over from one still running (see the loop below)
	var target: float = goal.get_goal().theta
	var start := _odom_yaw()
	var feedback := goal.create_feedback()
	var result := goal.create_result()
	while true:
		result.delta = wrapf(_odom_yaw() - start, -PI, PI)
		if _rotate_goal != goal: # Preempted by a newer goal
			goal.abort(result)
			return
		if goal.is_cancel_requested():
			_finish_rotation()
			goal.canceled(result)
			return
		var error := wrapf(target - _odom_yaw(), -PI, PI)
		if absf(error) < 0.01:
			break
		# Proportional turn, with a floor so it doesn't crawl the last few degrees
		var turn := clampf(4.0 * error, -max_angular_speed, max_angular_speed)
		drive(0.0, signf(turn) * maxf(absf(turn), 0.15))
		feedback.remaining = error
		goal.publish_feedback(feedback)
		await get_tree().physics_frame

	_finish_rotation()
	result.delta = wrapf(_odom_yaw() - start, -PI, PI)
	goal.succeed(result)


func _finish_rotation() -> void:
	stop()
	_rotate_goal = null


# --- Physics (unchanged from the starter) -----------------------------------------------------------

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
