extends RosMsg
class_name RosSensorMsgsMagneticField

const ROS_TYPE_NAME = "sensor_msgs/msg/MagneticField"

func _init():
	init(ROS_TYPE_NAME)

var header : RosStdMsgsHeader:
	get: return get_member(&"header")
	set(v): set_member(&"header", v)

var magnetic_field : RosGeometryMsgsVector3:
	get: return get_member(&"magnetic_field")
	set(v): set_member(&"magnetic_field", v)

var magnetic_field_covariance : PackedFloat64Array:
	get: return get_member(&"magnetic_field_covariance")
	set(v): set_member(&"magnetic_field_covariance", v)

