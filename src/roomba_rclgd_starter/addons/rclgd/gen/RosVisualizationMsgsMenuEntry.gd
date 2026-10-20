extends RosMsg
class_name RosVisualizationMsgsMenuEntry

const ROS_TYPE_NAME = "visualization_msgs/msg/MenuEntry"

func _init():
	init(ROS_TYPE_NAME)

var id : int:
	get: return get_member(&"id")
	set(v): set_member(&"id", v)

var parent_id : int:
	get: return get_member(&"parent_id")
	set(v): set_member(&"parent_id", v)

var title : String:
	get: return get_member(&"title")
	set(v): set_member(&"title", v)

var command : String:
	get: return get_member(&"command")
	set(v): set_member(&"command", v)

var command_type : int:
	get: return get_member(&"command_type")
	set(v): set_member(&"command_type", v)

