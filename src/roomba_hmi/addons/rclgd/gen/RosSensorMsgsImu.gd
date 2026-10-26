extends RosMsg
class_name RosSensorMsgsImu

const ROS_TYPE_NAME = "sensor_msgs/msg/Imu"

func _init():
	init(ROS_TYPE_NAME)

var header : RosStdMsgsHeader:
	get: return get_member(&"header")
	set(v): set_member(&"header", v)

var orientation : RosGeometryMsgsQuaternion:
	get: return get_member(&"orientation")
	set(v): set_member(&"orientation", v)

var orientation_covariance : PackedFloat64Array:
	get: return get_member(&"orientation_covariance")
	set(v): set_member(&"orientation_covariance", v)

var angular_velocity : RosGeometryMsgsVector3:
	get: return get_member(&"angular_velocity")
	set(v): set_member(&"angular_velocity", v)

var angular_velocity_covariance : PackedFloat64Array:
	get: return get_member(&"angular_velocity_covariance")
	set(v): set_member(&"angular_velocity_covariance", v)

var linear_acceleration : RosGeometryMsgsVector3:
	get: return get_member(&"linear_acceleration")
	set(v): set_member(&"linear_acceleration", v)

var linear_acceleration_covariance : PackedFloat64Array:
	get: return get_member(&"linear_acceleration_covariance")
	set(v): set_member(&"linear_acceleration_covariance", v)

