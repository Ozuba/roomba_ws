extends RosMsg
class_name RosVisualizationMsgsMeshFile

const ROS_TYPE_NAME = "visualization_msgs/msg/MeshFile"

func _init():
	init(ROS_TYPE_NAME)

var filename : String:
	get: return get_member(&"filename")
	set(v): set_member(&"filename", v)

var data : PackedByteArray:
	get: return get_member(&"data")
	set(v): set_member(&"data", v)

