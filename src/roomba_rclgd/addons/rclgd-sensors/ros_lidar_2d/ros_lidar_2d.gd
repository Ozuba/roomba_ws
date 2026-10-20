@icon("res://addons/rclgd-sensors/icons/ros_lidar_2d.svg")
class_name RosLidar2D
extends RosSensor
## Single-beam spinning lidar (a 2D laser scanner, like the ones on robot vacuums), simulated
## with physics raycasts. Publishes a LaserScan in the sensor's XY plane (ROS axes: 0 rad is
## forward, angles grow counterclockwise seen from above).
##
## The beam sweeps the scan over a revolution like the real sensor: each physics tick casts the
## rays whose turn has come, from the sensor's pose at that tick, so a moving scanner gets the
## same motion distortion a real one does. Rays only see collision shapes on collision_mask;
## the CollisionObject3Ds the sensor is mounted on are ignored.
##
## Ranges follow REP 117: +inf for no return within range_max, -inf for a return closer than
## range_min. Intensities are the cosine of the angle of incidence (1 = surface faces the beam).

@export_group("Sensor Settings")
## Rays per scan
@export_range(1, 8192) var samples: int = 360
## Start of the scan (degrees, counterclockwise from forward)
@export_range(-180.0, 180.0) var angle_min: float = -180.0
## End of the scan (degrees). A 360° span doesn't repeat the first ray at the end.
@export_range(-180.0, 180.0) var angle_max: float = 180.0
## Returns closer than this are invalid (m)
@export var range_min: float = 0.15
## Farthest return (m)
@export var range_max: float = 12.0
## Gaussian range noise (m)
@export var noise_std_dev: float = 0.01
## Physics layers the beam hits
@export_flags_3d_physics var collision_mask: int = 0xFFFFFFFF

@export_group("ROS 2 Settings")
## Revolutions per second; one scan is published per revolution
@export var publish_rate: float = 5.0
@export var scan_topic: String = "~/scan"

var _scan_pub: RosPublisher
var _msg := RosSensorMsgsLaserScan.new()
var _query := PhysicsRayQueryParameters3D.new()
var _ranges := PackedFloat32Array()
var _intensities := PackedFloat32Array()

var _angle_min: float # Radians
var _angle_increment: float
var _scan_time: float # Seconds per revolution
var _time_increment: float # Seconds between rays
var _scan_clock: float = 0.0 # Time since the current revolution started
var _next_ray: int = 0 # Index of the next ray to cast in the current scan

func _sensor_ready() -> void:
	_angle_min = deg_to_rad(angle_min)
	var span := deg_to_rad(angle_max - angle_min)
	var full_circle := span >= TAU - 0.001
	if full_circle:
		_angle_increment = TAU / samples
	else:
		_angle_increment = span / maxi(samples - 1, 1)
	_scan_time = 1.0 / publish_rate
	# The beam turns at a constant rate, also through the part of a partial scan that isn't kept
	_time_increment = _scan_time * _angle_increment / TAU

	_ranges.resize(samples)
	_intensities.resize(samples)

	_query.collision_mask = collision_mask
	_query.exclude = _mount_bodies()

	_scan_pub = _advertise(scan_topic, "sensor_msgs/msg/LaserScan")
	_msg.header.frame_id = _frame
	_msg.angle_min = _angle_min
	_msg.angle_max = _angle_min + _angle_increment * (samples - 1)
	_msg.angle_increment = _angle_increment
	_msg.time_increment = _time_increment
	_msg.scan_time = _scan_time
	_msg.range_min = range_min
	_msg.range_max = range_max

func _physics_process(delta: float) -> void:
	if not _scan_pub:
		return
	_scan_clock += delta
	# Several revolutions can end in one tick if publish_rate is above the physics tick rate
	while true:
		var space := get_world_3d().direct_space_state
		var origin := global_position
		var axes := global_basis.orthonormalized()
		while _next_ray < samples and _next_ray * _time_increment <= _scan_clock:
			_cast(space, origin, axes, _next_ray)
			_next_ray += 1
		if _scan_clock < _scan_time:
			break
		_publish()
		_scan_clock -= _scan_time
		_next_ray = 0

func _cast(space: PhysicsDirectSpaceState3D, origin: Vector3, axes: Basis, i: int) -> void:
	var angle := _angle_min + _angle_increment * i
	# ROS angle (counterclockwise from forward, about up) in Godot axes: forward -Z, left -X
	var dir := axes * Vector3(-sin(angle), 0.0, -cos(angle))
	_query.from = origin
	_query.to = origin + dir * range_max
	var hit := space.intersect_ray(_query)
	if hit.is_empty():
		_ranges[i] = INF
		_intensities[i] = 0.0
		return
	var distance := origin.distance_to(hit.position) + randfn(0.0, noise_std_dev)
	if distance < range_min:
		_ranges[i] = -INF
	elif distance > range_max:
		_ranges[i] = INF
	else:
		_ranges[i] = distance
	_intensities[i] = absf(dir.dot(hit.normal))

func _publish() -> void:
	# The header stamp is the time of the first ray, at the start of the revolution
	write_stamp(_msg.header, to_ns(_node.now()) - int(_scan_clock * 1e9))
	# Message arrays are copies: assign whole arrays, element writes would be lost
	_msg.ranges = _ranges
	_msg.intensities = _intensities
	_scan_pub.publish(_msg)

## RIDs of the CollisionObject3D ancestors, so the beam doesn't hit the robot it is mounted on
func _mount_bodies() -> Array[RID]:
	var rids: Array[RID] = []
	var node := get_parent()
	while node:
		if node is CollisionObject3D:
			rids.append(node.get_rid())
		node = node.get_parent()
	return rids
