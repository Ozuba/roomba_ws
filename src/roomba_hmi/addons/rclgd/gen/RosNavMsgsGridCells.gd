extends RosMsg
class_name RosNavMsgsGridCells

const ROS_TYPE_NAME = "nav_msgs/msg/GridCells"

func _init():
	init(ROS_TYPE_NAME)

var header : RosStdMsgsHeader:
	get: return get_member(&"header")
	set(v): set_member(&"header", v)

var cell_width : float:
	get: return get_member(&"cell_width")
	set(v): set_member(&"cell_width", v)

var cell_height : float:
	get: return get_member(&"cell_height")
	set(v): set_member(&"cell_height", v)

var cells : Array[RosGeometryMsgsPoint]:
	get: return get_member(&"cells")
	set(v): set_member(&"cells", v)

