extends RosMsg
class_name RosSensorMsgsChannelFloat32

const ROS_TYPE_NAME = "sensor_msgs/msg/ChannelFloat32"

func _init():
	init(ROS_TYPE_NAME)

var name : String:
	get: return get_member(&"name")
	set(v): set_member(&"name", v)

var values : PackedFloat32Array:
	get: return get_member(&"values")
	set(v): set_member(&"values", v)

