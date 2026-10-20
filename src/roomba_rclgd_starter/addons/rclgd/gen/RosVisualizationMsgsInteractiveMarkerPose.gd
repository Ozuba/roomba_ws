extends RosMsg
class_name RosVisualizationMsgsInteractiveMarkerPose

const ROS_TYPE_NAME = "visualization_msgs/msg/InteractiveMarkerPose"

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

