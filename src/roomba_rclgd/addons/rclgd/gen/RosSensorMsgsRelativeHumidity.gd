extends RosMsg
class_name RosSensorMsgsRelativeHumidity

const ROS_TYPE_NAME = "sensor_msgs/msg/RelativeHumidity"

func _init():
	init(ROS_TYPE_NAME)

var header : RosStdMsgsHeader:
	get: return get_member(&"header")
	set(v): set_member(&"header", v)

var relative_humidity : float:
	get: return get_member(&"relative_humidity")
	set(v): set_member(&"relative_humidity", v)

var variance : float:
	get: return get_member(&"variance")
	set(v): set_member(&"variance", v)

