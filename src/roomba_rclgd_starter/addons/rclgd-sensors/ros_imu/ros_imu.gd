@icon("res://addons/rclgd-sensors/icons/ros_imu.svg")
class_name RosImu
extends RosSensor
## IMU mounted on the nearest RigidBody3D ancestor (e.g. the car). Measures proper acceleration
## and angular velocity at its own position, with white noise and random-walk biases, plus its
## orientation. Samples every physics tick and publishes at publish_rate.

@export_group("Sensor Settings")
## Accelerometer white noise (m/s²)
@export var accel_noise_std: float = 0.05
## Gyroscope white noise (rad/s)
@export var gyro_noise_std: float = 0.005
## Orientation noise (rad, per axis)
@export var orientation_noise_std: float = 0.002
## Bias random walk, applied to both the accelerometer and the gyroscope (units per √s)
@export var bias_drift_std: float = 0.0001
## Time constant (s) of the accelerometer low-pass filter, which smooths the spikes of the
## physics solver. 0 disables it.
@export var lpf_tau: float = 0.01

@export_group("ROS 2 Settings")
## Publish rate (Hz). Samples come from physics ticks, so it is capped at the physics tick rate.
@export var publish_rate: float = 100.0

var _body: RigidBody3D
var _imu_pub: RosPublisher
var _msg := RosSensorMsgsImu.new()

var _has_last_velocity: bool = false # The first tick has no previous velocity to differentiate
var _last_velocity: Vector3
var _accel: Vector3 # Low-passed proper acceleration, sensor axes
var _gyro: Vector3 # Angular velocity, sensor axes
var _accel_bias: Vector3
var _gyro_bias: Vector3
var _since_publish: float = 0.0

func _sensor_ready() -> void:
	_body = _find_body()
	if not _body:
		push_warning("%s: no RigidBody3D ancestor to measure, the IMU won't publish" % name)
	if publish_rate > Engine.physics_ticks_per_second:
		push_warning("%s: publish_rate %.0f Hz is above the physics tick rate (%d Hz) and will be capped"
				% [name, publish_rate, Engine.physics_ticks_per_second])

	_imu_pub = _advertise("~/data", "sensor_msgs/msg/Imu")
	_msg.header.frame_id = _frame
	_fill_covariances()

func _physics_process(delta: float) -> void:
	if not _body or not _imu_pub:
		return
	var state := PhysicsServer3D.body_get_direct_state(_body.get_rid())

	# Differentiate the velocity of the mount point, not of the center of mass: that adds the
	# tangential (α×r) and centripetal (ω×(ω×r)) acceleration an off-center IMU feels
	var velocity := state.get_velocity_at_local_position(global_position - _body.global_position)
	if not _has_last_velocity:
		_last_velocity = velocity
		_has_last_velocity = true
		return
	# An accelerometer measures proper acceleration: kinematic acceleration minus gravity
	var accel_world := (velocity - _last_velocity) / delta - _body.get_gravity()
	_last_velocity = velocity

	var to_sensor := global_basis.orthonormalized().inverse()
	var accel := to_sensor * accel_world
	_accel = _accel.lerp(accel, 1.0 - exp(-delta / lpf_tau)) if lpf_tau > 0.0 else accel
	_gyro = to_sensor * state.angular_velocity

	var drift := bias_drift_std * sqrt(delta)
	_accel_bias += _noise(drift)
	_gyro_bias += _noise(drift)

	# Publish on the tick closest to each publish period
	var period := 1.0 / publish_rate
	_since_publish += delta
	if _since_publish + delta * 0.5 >= period:
		_since_publish = clampf(_since_publish - period, 0.0, period)
		_publish()

func _publish() -> void:
	_msg.header.stamp = _node.now()
	_set_xyz(_msg.linear_acceleration, to_ros(_accel + _accel_bias + _noise(accel_noise_std)))
	_set_xyz(_msg.angular_velocity, to_ros(_gyro + _gyro_bias + _noise(gyro_noise_std)))

	var orientation := global_basis.get_rotation_quaternion() \
			* Quaternion.from_euler(_noise(orientation_noise_std))
	var q := to_ros_quat(orientation)
	_msg.orientation.x = q.x
	_msg.orientation.y = q.y
	_msg.orientation.z = q.z
	_msg.orientation.w = q.w

	_imu_pub.publish(_msg)

func _fill_covariances() -> void:
	# All zeros means "unknown" in ROS, and GTSAM needs non-zero diagonals: keep a floor.
	# Message arrays are copies: assign whole arrays, element writes would be lost.
	_msg.linear_acceleration_covariance = _diagonal(accel_noise_std)
	_msg.angular_velocity_covariance = _diagonal(gyro_noise_std)
	_msg.orientation_covariance = _diagonal(orientation_noise_std)

static func _diagonal(std: float) -> PackedFloat64Array:
	var variance := maxf(std * std, 1e-9)
	return PackedFloat64Array([variance, 0.0, 0.0, 0.0, variance, 0.0, 0.0, 0.0, variance])

func _find_body() -> RigidBody3D:
	var node := get_parent()
	while node and not node is RigidBody3D:
		node = node.get_parent()
	return node as RigidBody3D

static func _set_xyz(target: RosMsg, v: Vector3) -> void:
	target.x = v.x
	target.y = v.y
	target.z = v.z

static func _noise(std: float) -> Vector3:
	return Vector3(randfn(0.0, std), randfn(0.0, std), randfn(0.0, std))
