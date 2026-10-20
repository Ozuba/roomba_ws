extends RosMsg
class_name RosVisualizationMsgsImageMarker

const ROS_TYPE_NAME = "visualization_msgs/msg/ImageMarker"

func _init():
	init(ROS_TYPE_NAME)

var header : RosStdMsgsHeader:
	get: return get_member(&"header")
	set(v): set_member(&"header", v)

var ns : String:
	get: return get_member(&"ns")
	set(v): set_member(&"ns", v)

var id : int:
	get: return get_member(&"id")
	set(v): set_member(&"id", v)

var type : int:
	get: return get_member(&"type")
	set(v): set_member(&"type", v)

var action : int:
	get: return get_member(&"action")
	set(v): set_member(&"action", v)

var position : RosGeometryMsgsPoint:
	get: return get_member(&"position")
	set(v): set_member(&"position", v)

var scale : float:
	get: return get_member(&"scale")
	set(v): set_member(&"scale", v)

var outline_color : RosStdMsgsColorRgba:
	get: return get_member(&"outline_color")
	set(v): set_member(&"outline_color", v)

var filled : int:
	get: return get_member(&"filled")
	set(v): set_member(&"filled", v)

var fill_color : RosStdMsgsColorRgba:
	get: return get_member(&"fill_color")
	set(v): set_member(&"fill_color", v)

var lifetime : RosBuiltinInterfacesDuration:
	get: return get_member(&"lifetime")
	set(v): set_member(&"lifetime", v)

var points : Array[RosGeometryMsgsPoint]:
	get: return get_member(&"points")
	set(v): set_member(&"points", v)

var outline_colors : Array[RosStdMsgsColorRgba]:
	get: return get_member(&"outline_colors")
	set(v): set_member(&"outline_colors", v)

