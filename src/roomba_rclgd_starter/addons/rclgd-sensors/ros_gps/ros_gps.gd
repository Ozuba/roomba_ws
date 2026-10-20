@icon("res://addons/rclgd-sensors/icons/ros_gps.svg")
class_name RosGps
extends RosSensor
## GNSS receiver publishing NavSatFix. The Godot world origin is at origin_lat/lon/alt and the
## world axes, in ROS convention, are ENU (x east, y north, z up), like the map frame (REP 103).
## The position error is a first-order Gauss-Markov process: it drifts slowly, like real GNSS
## error, with standard deviation position_std / altitude_std.

const WGS84_A = 6378137.0
const WGS84_F = 1.0 / 298.257223563
const WGS84_E2 = WGS84_F * (2.0 - WGS84_F)

@export_group("Sensor Settings")
## Latitude of the Godot origin (degrees)
@export var origin_lat: float = 42.8125
## Longitude of the Godot origin (degrees)
@export var origin_lon: float = -1.6458
## Altitude of the Godot origin (meters)
@export var origin_alt: float = 450.0
## Horizontal error standard deviation (m)
@export var position_std: float = 0.5
## Vertical error standard deviation (m)
@export var altitude_std: float = 1.2
## How long the error takes to decorrelate (s). 0 gives independent (white) noise per fix.
@export var error_correlation_time: float = 5.0

@export_group("ROS 2 Settings")
## Fix rate (Hz)
@export var publish_rate: float = 10.0

var _gps_pub: RosPublisher
var _msg := RosSensorMsgsNavSatFix.new()
var _error := Vector3.ZERO # ENU error (m)
var _has_error: bool = false # The first fix draws the error from its stationary distribution

func _sensor_ready() -> void:
	_gps_pub = _advertise("~/fix", "sensor_msgs/msg/NavSatFix")
	_msg.header.frame_id = _frame
	_msg.status.status = 0 # STATUS_FIX
	_msg.status.service = 1 # SERVICE_GPS
	# Message arrays are copies: assign the whole array, element writes would be lost
	var h_var := position_std * position_std
	_msg.position_covariance = PackedFloat64Array([h_var, 0.0, 0.0, 0.0, h_var, 0.0, 0.0, 0.0, altitude_std * altitude_std])
	_msg.position_covariance_type = 2 # COVARIANCE_TYPE_DIAGONAL_KNOWN
	_start_sampling(publish_rate)

func _sample() -> void:
	_update_error(1.0 / publish_rate)
	var enu := to_ros(global_position) + _error

	# Local flat-earth approximation around the origin: meridian (M) and prime vertical (N) radii
	var phi := deg_to_rad(origin_lat)
	var den := sqrt(1.0 - WGS84_E2 * sin(phi) * sin(phi))
	var m := WGS84_A * (1.0 - WGS84_E2) / (den * den * den)
	var n := WGS84_A / den

	_msg.header.stamp = _node.now()
	_msg.latitude = origin_lat + rad_to_deg(enu.y / m)
	_msg.longitude = origin_lon + rad_to_deg(enu.x / (n * cos(phi)))
	_msg.altitude = origin_alt + enu.z
	_gps_pub.publish(_msg)

## Advances the error by dt. The decay keeps its stationary standard deviation at the configured
## values, so the published covariance stays valid.
func _update_error(dt: float) -> void:
	var decay := exp(-dt / error_correlation_time) if _has_error and error_correlation_time > 0.0 else 0.0
	var innovation := Vector3(randfn(0.0, position_std), randfn(0.0, position_std), randfn(0.0, altitude_std))
	_error = _error * decay + innovation * sqrt(1.0 - decay * decay)
	_has_error = true
