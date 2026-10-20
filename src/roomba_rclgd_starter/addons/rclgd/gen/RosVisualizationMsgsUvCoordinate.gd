extends RosMsg
class_name RosVisualizationMsgsUvCoordinate

const ROS_TYPE_NAME = "visualization_msgs/msg/UVCoordinate"

func _init():
	init(ROS_TYPE_NAME)

var u : float:
	get: return get_member(&"u")
	set(v): set_member(&"u", v)

var v : float:
	get: return get_member(&"v")
	set(v): set_member(&"v", v)

