extends RosMsg
class_name RosSensorMsgsTemperature

const ROS_TYPE_NAME = "sensor_msgs/msg/Temperature"

func _init():
	init(ROS_TYPE_NAME)

var header : RosStdMsgsHeader:
	get: return get_member(&"header")
	set(v): set_member(&"header", v)

var temperature : float:
	get: return get_member(&"temperature")
	set(v): set_member(&"temperature", v)

var variance : float:
	get: return get_member(&"variance")
	set(v): set_member(&"variance", v)

