extends RosMsg
class_name RosSensorMsgsTimeReference

const ROS_TYPE_NAME = "sensor_msgs/msg/TimeReference"

func _init():
	init(ROS_TYPE_NAME)

var header : RosStdMsgsHeader:
	get: return get_member(&"header")
	set(v): set_member(&"header", v)

var time_ref : RosBuiltinInterfacesTime:
	get: return get_member(&"time_ref")
	set(v): set_member(&"time_ref", v)

var source : String:
	get: return get_member(&"source")
	set(v): set_member(&"source", v)

