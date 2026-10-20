extends RosMsg
class_name RosSensorMsgsPointCloud

const ROS_TYPE_NAME = "sensor_msgs/msg/PointCloud"

func _init():
	init(ROS_TYPE_NAME)

var header : RosStdMsgsHeader:
	get: return get_member(&"header")
	set(v): set_member(&"header", v)

var points : Array[RosGeometryMsgsPoint32]:
	get: return get_member(&"points")
	set(v): set_member(&"points", v)

var channels : Array[RosSensorMsgsChannelFloat32]:
	get: return get_member(&"channels")
	set(v): set_member(&"channels", v)

