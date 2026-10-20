extends RosMsg
class_name RosSensorMsgsRange

const ROS_TYPE_NAME = "sensor_msgs/msg/Range"

func _init():
	init(ROS_TYPE_NAME)

var header : RosStdMsgsHeader:
	get: return get_member(&"header")
	set(v): set_member(&"header", v)

var radiation_type : int:
	get: return get_member(&"radiation_type")
	set(v): set_member(&"radiation_type", v)

var field_of_view : float:
	get: return get_member(&"field_of_view")
	set(v): set_member(&"field_of_view", v)

var min_range : float:
	get: return get_member(&"min_range")
	set(v): set_member(&"min_range", v)

var max_range : float:
	get: return get_member(&"max_range")
	set(v): set_member(&"max_range", v)

var range : float:
	get: return get_member(&"range")
	set(v): set_member(&"range", v)

var variance : float:
	get: return get_member(&"variance")
	set(v): set_member(&"variance", v)

