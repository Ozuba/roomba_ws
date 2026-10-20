extends RosMsg
class_name RosVisualizationMsgsMarkerArray

const ROS_TYPE_NAME = "visualization_msgs/msg/MarkerArray"

func _init():
	init(ROS_TYPE_NAME)

var markers : Array[RosVisualizationMsgsMarker]:
	get: return get_member(&"markers")
	set(v): set_member(&"markers", v)

