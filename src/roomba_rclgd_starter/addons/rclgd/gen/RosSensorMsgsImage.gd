extends RosMsg
class_name RosSensorMsgsImage

const ROS_TYPE_NAME = "sensor_msgs/msg/Image"

func _init():
	init(ROS_TYPE_NAME)

var header : RosStdMsgsHeader:
	get: return get_member(&"header")
	set(v): set_member(&"header", v)

var height : int:
	get: return get_member(&"height")
	set(v): set_member(&"height", v)

var width : int:
	get: return get_member(&"width")
	set(v): set_member(&"width", v)

var encoding : String:
	get: return get_member(&"encoding")
	set(v): set_member(&"encoding", v)

var is_bigendian : int:
	get: return get_member(&"is_bigendian")
	set(v): set_member(&"is_bigendian", v)

var step : int:
	get: return get_member(&"step")
	set(v): set_member(&"step", v)

var data : PackedByteArray:
	get: return get_member(&"data")
	set(v): set_member(&"data", v)

