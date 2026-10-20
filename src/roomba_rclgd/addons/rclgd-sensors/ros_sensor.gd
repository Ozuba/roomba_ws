@abstract
class_name RosSensor
extends Node3D
## Base of the rclgd sensors. Owns the sensor's ROS node, publishes its mount transform once
## (sensors are rigidly attached to their parent) and calls _sample() at a fixed rate.
##
## Subclasses set up their publishers in _sensor_ready() and either call
## _start_sampling(rate) to get _sample() calls, or sample on their own (e.g. per physics tick).

const PublishQueue = preload("res://addons/rclgd-sensors/publish_queue.gd")

@export_group("ROS 2 Settings")
## Namespace of the sensor's node, topics and frames
@export var ros_namespace: String = ""
## TF frame of the sensor. Empty uses the node name in snake_case. A leading "~" puts the frame
## under ros_namespace ("~lidar" -> "<namespace>/lidar")
@export var frame_id: String = ""
## TF frame the sensor's transform (relative to its parent node) is published in
@export var parent_frame_id: String = "~base_link"

var _node: RosNode
var _tf_broadcaster: RosTfBroadcaster
var _frame: String # Resolved frame_id, for message headers
var _timer: RosTimer
var _publish_queues: Array[PublishQueue] = []

func _ready() -> void:
	_node = RosNode.new()
	_node.init(name.to_snake_case(), ros_namespace.to_snake_case())
	_tf_broadcaster = _node.create_tf_broadcaster()
	_frame = _node.resolve_frame(_frame_name())
	_tf_broadcaster.send_transform(transform, _frame_name(), parent_frame_id, true)
	_sensor_ready()

func _notification(what: int) -> void:
	# Publishing threads use the sensor and the ROS context. Stop them on leaving the tree: the
	# ROS autoload shuts the context down in its own _exit_tree, and a publish after that aborts.
	if what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_PREDELETE:
		for queue in _publish_queues:
			queue.stop()
	elif what == NOTIFICATION_ENTER_TREE:
		for queue in _publish_queues:
			queue.start()

## Sets up the sensor once its ROS node exists
func _sensor_ready() -> void:
	pass

## Takes one sample; called at the rate given to _start_sampling()
func _sample() -> void:
	pass

## Calls _sample() every 1/rate seconds. The first call is at a random phase, so sensors with
## the same rate don't all sample (and publish) in the same frame.
func _start_sampling(rate: float) -> void:
	var interval := 1.0 / rate
	await get_tree().create_timer(randf() * interval).timeout
	_timer = _node.create_timer(interval, _sample)

## The unresolved TF frame name of the sensor
func _frame_name() -> String:
	return frame_id if not frame_id.is_empty() else "~" + name.to_snake_case()

## Publisher with sensor-data QoS, matching rclcpp::SensorDataQoS: best effort, keep last 5,
## volatile. Stale sensor data is useless, so dropped samples are not retransmitted.
## Subscribers must use best effort too: a reliable subscriber does not match.
func _advertise(topic: String, type: String) -> RosPublisher:
	var qos := RosQoS.new()
	qos.set_reliability(RosQoS.BEST_EFFORT)
	qos.set_history(RosQoS.KEEP_LAST)
	qos.set_depth(5)
	qos.set_durability(RosQoS.VOLATILE)
	return _node.create_publisher(topic, type, qos)

## Queue that runs publish_fn on its own thread, in order; stopped when the sensor is freed
func _create_publish_queue(publish_fn: Callable) -> PublishQueue:
	var queue := PublishQueue.new(publish_fn)
	_publish_queues.append(queue)
	return queue

## A ROS time as nanoseconds. GPU readback callbacks carry stamps as plain ints: a pending
## callback still holding a RosMsg at engine shutdown releases it after rclgd is unloaded (crash).
static func to_ns(time: RosMsg) -> int:
	return time.sec * 1_000_000_000 + time.nanosec

## Sets a Header's stamp from nanoseconds
@warning_ignore("integer_division")
static func write_stamp(header: RosMsg, ns: int) -> void:
	header.stamp.sec = ns / 1_000_000_000
	header.stamp.nanosec = ns % 1_000_000_000

## Godot axes (forward -Z, left -X, up +Y) to ROS axes (forward +X, left +Y, up +Z)
static func to_ros(v: Vector3) -> Vector3:
	return Vector3(-v.z, -v.x, v.y)

## Rotation expressed in ROS axes. The axis change is a proper rotation, so it maps the
## quaternion's vector part like any other vector.
static func to_ros_quat(q: Quaternion) -> Quaternion:
	var v := to_ros(Vector3(q.x, q.y, q.z))
	return Quaternion(v.x, v.y, v.z, q.w)
