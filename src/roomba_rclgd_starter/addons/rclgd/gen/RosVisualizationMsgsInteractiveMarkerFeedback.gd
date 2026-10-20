extends RosMsg
class_name RosVisualizationMsgsInteractiveMarkerFeedback

const ROS_TYPE_NAME = "visualization_msgs/msg/InteractiveMarkerFeedback"

func _init():
	init(ROS_TYPE_NAME)

var header : RosStdMsgsHeader:
	get: return get_member(&"header")
	set(v): set_member(&"header", v)

var client_id : String:
	get: return get_member(&"client_id")
	set(v): set_member(&"client_id", v)

var marker_name : String:
	get: return get_member(&"marker_name")
	set(v): set_member(&"marker_name", v)

var control_name : String:
	get: return get_member(&"control_name")
	set(v): set_member(&"control_name", v)

var event_type : int:
	get: return get_member(&"event_type")
	set(v): set_member(&"event_type", v)

var pose : RosGeometryMsgsPose:
	get: return get_member(&"pose")
	set(v): set_member(&"pose", v)

var menu_entry_id : int:
	get: return get_member(&"menu_entry_id")
	set(v): set_member(&"menu_entry_id", v)

var mouse_point : RosGeometryMsgsPoint:
	get: return get_member(&"mouse_point")
	set(v): set_member(&"mouse_point", v)

var mouse_point_valid : bool:
	get: return get_member(&"mouse_point_valid")
	set(v): set_member(&"mouse_point_valid", v)

