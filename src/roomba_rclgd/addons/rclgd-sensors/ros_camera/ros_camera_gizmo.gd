@tool
extends "res://addons/rclgd-sensors/sensor_gizmo.gd"
## Pinhole frustum for RosCamera: vertical `fov`, aspect from `resolution`, up marker on top.

func _init() -> void:
	create_material("main", Color(0.8, 0.5, 1.0))
	create_material("depth", Color(0.4, 0.9, 1.0))

func _get_gizmo_name() -> String:
	return "RosCamera"

func _has_gizmo(node: Node3D) -> bool:
	return node is RosCamera

func _draw_sensor(gizmo: EditorNode3DGizmo, node: Node3D) -> void:
	var res: Vector2i = node.resolution
	var aspect := float(res.x) / maxi(res.y, 1)
	var d := minf(DISPLAY_RANGE, node.far)
	var h := d * tan(deg_to_rad(clampf(node.fov, 1.0, 179.0)) * 0.5)
	var w := h * aspect

	var tl := Vector3(-w, h, -d)
	var tr := Vector3(w, h, -d)
	var br := Vector3(w, -h, -d)
	var bl := Vector3(-w, -h, -d)

	var lines := PackedVector3Array()
	for corner in [tl, tr, br, bl]:
		lines.append(Vector3.ZERO)
		lines.append(corner)
	add_polyline(lines, PackedVector3Array([tl, tr, br, bl]), true)
	# Up marker, so the image orientation is visible
	add_polyline(lines, PackedVector3Array([
		Vector3(-w * 0.3, h * 1.1, -d), Vector3(0, h * 1.4, -d), Vector3(w * 0.3, h * 1.1, -d)
	]), true)
	commit(gizmo, lines)

	if node.publish_depth:
		# Inner rectangle marks cameras that also publish depth
		var depth_lines := PackedVector3Array()
		add_polyline(depth_lines, PackedVector3Array([tl * 0.5, tr * 0.5, br * 0.5, bl * 0.5]), true)
		commit(gizmo, depth_lines, "depth")
