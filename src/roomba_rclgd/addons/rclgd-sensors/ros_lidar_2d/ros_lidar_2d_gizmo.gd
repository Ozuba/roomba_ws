@tool
extends "res://addons/rclgd-sensors/sensor_gizmo.gd"
## Scan plane for RosLidar2D: the scanned arc with spokes every 45 degrees (same ray directions
## as RosLidar2D._cast), plus the sensor puck.

const SEGMENTS: int = 64

func _init() -> void:
	create_material("main", Color(1.0, 0.45, 0.3))

func _get_gizmo_name() -> String:
	return "RosLidar2D"

func _has_gizmo(node: Node3D) -> bool:
	return node is RosLidar2D

func _draw_sensor(gizmo: EditorNode3DGizmo, node: Node3D) -> void:
	# The scanner's angles grow counterclockwise (to the left), the gizmo azimuths to the right
	var a_min := deg_to_rad(node.angle_min)
	var a_max := deg_to_rad(node.angle_max)
	var full_circle := absf(a_max - a_min) >= TAU - 0.001
	var r := DISPLAY_RANGE

	var lines := PackedVector3Array()

	var points := PackedVector3Array()
	for i in range(SEGMENTS + 1):
		points.append(direction(-lerpf(a_min, a_max, float(i) / SEGMENTS), 0.0) * r)
	add_polyline(lines, points, full_circle)

	# Spokes every 45 degrees, and at the limits of a partial scan
	var angles := []
	var a := ceilf(a_min / (PI / 4)) * (PI / 4)
	while a <= a_max + 0.001:
		angles.append(a)
		a += PI / 4
	if not full_circle:
		angles.append_array([a_min, a_max])
	for angle in angles:
		lines.append(Vector3.ZERO)
		lines.append(direction(-angle, 0.0) * r)

	# Flat sensor puck, with a tick pointing forward (angle 0)
	for y in [-0.02, 0.02]:
		add_circle(lines, Vector3(0, y, 0), Vector3.RIGHT, Vector3.BACK, 0.05, 16)
	lines.append(Vector3(0, 0, -0.05))
	lines.append(Vector3(0, 0, -0.1))
	commit(gizmo, lines)
