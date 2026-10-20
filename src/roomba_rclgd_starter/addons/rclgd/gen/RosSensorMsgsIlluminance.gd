extends RosMsg
class_name RosSensorMsgsIlluminance

const ROS_TYPE_NAME = "sensor_msgs/msg/Illuminance"

func _init():
	init(ROS_TYPE_NAME)

var header : RosStdMsgsHeader:
	get: return get_member(&"header")
	set(v): set_member(&"header", v)

var illuminance : float:
	get: return get_member(&"illuminance")
	set(v): set_member(&"illuminance", v)

var variance : float:
	get: return get_member(&"variance")
	set(v): set_member(&"variance", v)

