extends RosMsg
class_name RosNavMsgsOccupancyGrid

const ROS_TYPE_NAME = "nav_msgs/msg/OccupancyGrid"

func _init():
	init(ROS_TYPE_NAME)

var header : RosStdMsgsHeader:
	get: return get_member(&"header")
	set(v): set_member(&"header", v)

var info : RosNavMsgsMapMetaData:
	get: return get_member(&"info")
	set(v): set_member(&"info", v)

var data : PackedInt32Array:
	get: return get_member(&"data")
	set(v): set_member(&"data", v)

