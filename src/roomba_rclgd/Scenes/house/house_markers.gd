extends Node
## Publishes the house as a visualization_msgs/MarkerArray in the map frame, so RViz shows
## the same flat the robot drives in. Each box, cylinder and sphere mesh becomes one marker.
##
## The array is sent once with transient-local durability ("latched"): RViz gets it even if it
## starts after the simulator, as long as its display uses the same durability.

## Root of the scene to mirror
@export var house: Node3D
@export var topic: String = "/house/markers"
## Subtrees that are not part of the flat (e.g. the garden around it)
@export var skip: Array[String] = ["Garden"]

const CUBE := 1
const SPHERE := 2
const CYLINDER := 3

var _node: RosNode
var _pub: RosPublisher


func _ready() -> void:
	_node = RosNode.new()
	_node.init("house")

	var qos := RosQoS.new()
	qos.set_reliability(RosQoS.RELIABLE)
	qos.set_durability(RosQoS.TRANSIENT_LOCAL)
	qos.set_history(RosQoS.KEEP_LAST)
	qos.set_depth(1)
	_pub = _node.create_publisher(topic, "visualization_msgs/msg/MarkerArray", qos)

	var array := RosVisualizationMsgsMarkerArray.new()
	var markers: Array = []
	_collect(house, markers)
	array.markers = markers # Message arrays are copies: assign the whole array at once
	_pub.publish(array)
	print("[house] published %d markers on %s" % [markers.size(), topic])


func _collect(node: Node, markers: Array) -> void:
	if node.name in skip:
		return
	if node is MeshInstance3D:
		var marker := _to_marker(node, markers.size())
		if marker:
			markers.append(marker)
	for child in node.get_children():
		_collect(child, markers)


func _to_marker(mi: MeshInstance3D, id: int) -> RosMsg:
	var m := RosVisualizationMsgsMarker.new()
	var mesh := mi.mesh
	# Mesh sizes are in Godot axes; ROS x, y, z map to Godot -z, -x, y (sizes are unsigned)
	if mesh is BoxMesh:
		m.type = CUBE
		_set_scale(m, Vector3(mesh.size.z, mesh.size.x, mesh.size.y))
	elif mesh is CylinderMesh:
		m.type = CYLINDER
		var d := 2.0 * maxf(mesh.top_radius, mesh.bottom_radius)
		_set_scale(m, Vector3(d, d, mesh.height))
	elif mesh is SphereMesh:
		m.type = SPHERE
		_set_scale(m, Vector3.ONE * 2.0 * mesh.radius)
	else:
		return null

	m.header.frame_id = "map"
	m.header.stamp = _node.now()
	m.ns = String(mi.get_parent().name)
	m.id = id
	var p := rclgd.godot_to_ros_vector(mi.global_position)
	m.pose.position.x = p.x
	m.pose.position.y = p.y
	m.pose.position.z = p.z
	var q := rclgd.godot_to_ros_quat(mi.global_basis.get_rotation_quaternion())
	m.pose.orientation.x = q.x
	m.pose.orientation.y = q.y
	m.pose.orientation.z = q.z
	m.pose.orientation.w = q.w

	var color := _color_of(mesh.material)
	m.color.r = color.r
	m.color.g = color.g
	m.color.b = color.b
	m.color.a = 1.0
	return m


static func _set_scale(m: RosMsg, s: Vector3) -> void:
	m.scale.x = s.x
	m.scale.y = s.y
	m.scale.z = s.z


static func _color_of(material: Material) -> Color:
	if material is StandardMaterial3D:
		return material.albedo_color
	if material is ShaderMaterial:
		# The procedural floors: use their main colour parameter
		for param in ["color_light", "tile_color"]:
			var value = material.get_shader_parameter(param)
			if value is Color:
				return value
			if value is Vector3:
				return Color(value.x, value.y, value.z)
		return Color(0.66, 0.48, 0.31) if "planks" in material.resource_name else Color(0.86, 0.85, 0.82)
	return Color(0.7, 0.7, 0.7)
