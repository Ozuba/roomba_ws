extends RosMsg
class_name RosNavMsgsMapMetaData

const ROS_TYPE_NAME = "nav_msgs/msg/MapMetaData"

func _init():
	init(ROS_TYPE_NAME)

var map_load_time : RosBuiltinInterfacesTime:
	get: return get_member(&"map_load_time")
	set(v): set_member(&"map_load_time", v)

var resolution : float:
	get: return get_member(&"resolution")
	set(v): set_member(&"resolution", v)

var width : int:
	get: return get_member(&"width")
	set(v): set_member(&"width", v)

var height : int:
	get: return get_member(&"height")
	set(v): set_member(&"height", v)

var origin : RosGeometryMsgsPose:
	get: return get_member(&"origin")
	set(v): set_member(&"origin", v)

