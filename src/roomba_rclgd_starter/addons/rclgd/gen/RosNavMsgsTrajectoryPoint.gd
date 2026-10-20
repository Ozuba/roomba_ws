extends RosMsg
class_name RosNavMsgsTrajectoryPoint

const ROS_TYPE_NAME = "nav_msgs/msg/TrajectoryPoint"

func _init():
	init(ROS_TYPE_NAME)

var header : RosStdMsgsHeader:
	get: return get_member(&"header")
	set(v): set_member(&"header", v)

var pose : RosGeometryMsgsPose:
	get: return get_member(&"pose")
	set(v): set_member(&"pose", v)

var velocity : RosGeometryMsgsTwist:
	get: return get_member(&"velocity")
	set(v): set_member(&"velocity", v)

var acceleration : RosGeometryMsgsAccel:
	get: return get_member(&"acceleration")
	set(v): set_member(&"acceleration", v)

var effort : RosGeometryMsgsWrench:
	get: return get_member(&"effort")
	set(v): set_member(&"effort", v)

