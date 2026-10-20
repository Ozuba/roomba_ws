extends RosMsg
class_name RosVisualizationMsgsInteractiveMarkerControl

const ROS_TYPE_NAME = "visualization_msgs/msg/InteractiveMarkerControl"

func _init():
	init(ROS_TYPE_NAME)

var name : String:
	get: return get_member(&"name")
	set(v): set_member(&"name", v)

var orientation : RosGeometryMsgsQuaternion:
	get: return get_member(&"orientation")
	set(v): set_member(&"orientation", v)

var orientation_mode : int:
	get: return get_member(&"orientation_mode")
	set(v): set_member(&"orientation_mode", v)

var interaction_mode : int:
	get: return get_member(&"interaction_mode")
	set(v): set_member(&"interaction_mode", v)

var always_visible : bool:
	get: return get_member(&"always_visible")
	set(v): set_member(&"always_visible", v)

var markers : Array[RosVisualizationMsgsMarker]:
	get: return get_member(&"markers")
	set(v): set_member(&"markers", v)

var independent_marker_orientation : bool:
	get: return get_member(&"independent_marker_orientation")
	set(v): set_member(&"independent_marker_orientation", v)

var description : String:
	get: return get_member(&"description")
	set(v): set_member(&"description", v)

