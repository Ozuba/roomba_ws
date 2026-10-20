extends RosMsg
class_name RosVisualizationMsgsMarker

const ROS_TYPE_NAME = "visualization_msgs/msg/Marker"

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

var pose : RosGeometryMsgsPose:
	get: return get_member(&"pose")
	set(v): set_member(&"pose", v)

var scale : RosGeometryMsgsVector3:
	get: return get_member(&"scale")
	set(v): set_member(&"scale", v)

var color : RosStdMsgsColorRgba:
	get: return get_member(&"color")
	set(v): set_member(&"color", v)

var lifetime : RosBuiltinInterfacesDuration:
	get: return get_member(&"lifetime")
	set(v): set_member(&"lifetime", v)

var frame_locked : bool:
	get: return get_member(&"frame_locked")
	set(v): set_member(&"frame_locked", v)

var points : Array[RosGeometryMsgsPoint]:
	get: return get_member(&"points")
	set(v): set_member(&"points", v)

var colors : Array[RosStdMsgsColorRgba]:
	get: return get_member(&"colors")
	set(v): set_member(&"colors", v)

var texture_resource : String:
	get: return get_member(&"texture_resource")
	set(v): set_member(&"texture_resource", v)

var texture : RosSensorMsgsCompressedImage:
	get: return get_member(&"texture")
	set(v): set_member(&"texture", v)

var uv_coordinates : Array[RosVisualizationMsgsUvCoordinate]:
	get: return get_member(&"uv_coordinates")
	set(v): set_member(&"uv_coordinates", v)

var text : String:
	get: return get_member(&"text")
	set(v): set_member(&"text", v)

var mesh_resource : String:
	get: return get_member(&"mesh_resource")
	set(v): set_member(&"mesh_resource", v)

var mesh_file : RosVisualizationMsgsMeshFile:
	get: return get_member(&"mesh_file")
	set(v): set_member(&"mesh_file", v)

var mesh_use_embedded_materials : bool:
	get: return get_member(&"mesh_use_embedded_materials")
	set(v): set_member(&"mesh_use_embedded_materials", v)

