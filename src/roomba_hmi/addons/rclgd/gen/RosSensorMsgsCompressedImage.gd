extends RosMsg
class_name RosSensorMsgsCompressedImage

const ROS_TYPE_NAME = "sensor_msgs/msg/CompressedImage"

func _init():
	init(ROS_TYPE_NAME)

var header : RosStdMsgsHeader:
	get: return get_member(&"header")
	set(v): set_member(&"header", v)

var format : String:
	get: return get_member(&"format")
	set(v): set_member(&"format", v)

var data : PackedByteArray:
	get: return get_member(&"data")
	set(v): set_member(&"data", v)

