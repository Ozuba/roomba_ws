extends RosMsg
class_name RosSensorMsgsJoy

const ROS_TYPE_NAME = "sensor_msgs/msg/Joy"

func _init():
	init(ROS_TYPE_NAME)

var header : RosStdMsgsHeader:
	get: return get_member(&"header")
	set(v): set_member(&"header", v)

var axes : PackedFloat32Array:
	get: return get_member(&"axes")
	set(v): set_member(&"axes", v)

var buttons : PackedInt32Array:
	get: return get_member(&"buttons")
	set(v): set_member(&"buttons", v)

