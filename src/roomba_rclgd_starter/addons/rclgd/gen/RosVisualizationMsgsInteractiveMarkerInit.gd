extends RosMsg
class_name RosVisualizationMsgsInteractiveMarkerInit

const ROS_TYPE_NAME = "visualization_msgs/msg/InteractiveMarkerInit"

func _init():
	init(ROS_TYPE_NAME)

var server_id : String:
	get: return get_member(&"server_id")
	set(v): set_member(&"server_id", v)

var seq_num : int:
	get: return get_member(&"seq_num")
	set(v): set_member(&"seq_num", v)

var markers : Array[RosVisualizationMsgsInteractiveMarker]:
	get: return get_member(&"markers")
	set(v): set_member(&"markers", v)

