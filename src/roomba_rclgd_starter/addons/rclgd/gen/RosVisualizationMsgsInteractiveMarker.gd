extends RosMsg
class_name RosVisualizationMsgsInteractiveMarker

const ROS_TYPE_NAME = "visualization_msgs/msg/InteractiveMarker"

func _init():
	init(ROS_TYPE_NAME)

var header : RosStdMsgsHeader:
	get: return get_member(&"header")
	set(v): set_member(&"header", v)

var pose : RosGeometryMsgsPose:
	get: return get_member(&"pose")
	set(v): set_member(&"pose", v)

var name : String:
	get: return get_member(&"name")
	set(v): set_member(&"name", v)

var description : String:
	get: return get_member(&"description")
	set(v): set_member(&"description", v)

var scale : float:
	get: return get_member(&"scale")
	set(v): set_member(&"scale", v)

var menu_entries : Array[RosVisualizationMsgsMenuEntry]:
	get: return get_member(&"menu_entries")
	set(v): set_member(&"menu_entries", v)

var controls : Array[RosVisualizationMsgsInteractiveMarkerControl]:
	get: return get_member(&"controls")
	set(v): set_member(&"controls", v)

