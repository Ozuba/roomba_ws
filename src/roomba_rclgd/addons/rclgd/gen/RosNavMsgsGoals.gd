extends RosMsg
class_name RosNavMsgsGoals

const ROS_TYPE_NAME = "nav_msgs/msg/Goals"

func _init():
	init(ROS_TYPE_NAME)

var header : RosStdMsgsHeader:
	get: return get_member(&"header")
	set(v): set_member(&"header", v)

var goals : Array[RosGeometryMsgsPoseStamped]:
	get: return get_member(&"goals")
	set(v): set_member(&"goals", v)

