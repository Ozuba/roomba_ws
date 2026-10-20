@tool
extends "res://addons/rclgd-sensors/sensor_gizmo.gd"
## Scan volume for RosLidar: horizontal and vertical FOV limits drawn on a sphere
## (same ray directions as LidarStitch.glsl), plus the sensor puck.

const SEGMENTS: int = 64

func _init() -> void:
	create_material("main", Color(1.0, 0.45, 0.3))

func _get_gizmo_name() -> String:
	return "RosLidar"

func _has_gizmo(node: Node3D) -> bool:
	return node is RosLidar

func _draw_sensor(gizmo: EditorNode3DGizmo, node: Node3D) -> void:
	var h_min := deg_to_rad(node.horizontal_fov_min)
	var h_max := deg_to_rad(node.horizontal_fov_max)
	var v_min := deg_to_rad(clampf(node.vertical_fov_min, -90.0, 90.0))
	var v_max := deg_to_rad(clampf(node.vertical_fov_max, -90.0, 90.0))
	var full_circle := absf(h_max - h_min) >= TAU - 0.001
	var r := DISPLAY_RANGE

	var lines := PackedVector3Array()

	# Top and bottom scan lines, plus the horizon when it is inside the vertical FOV
	var elevations := [v_min, v_max]
	if v_min < 0.0 and v_max > 0.0:
		elevations.append(0.0)
	for elevation in elevations:
		var points := PackedVector3Array()
		for i in range(SEGMENTS + 1):
			points.append(direction(lerpf(h_min, h_max, float(i) / SEGMENTS), elevation) * r)
		add_polyline(lines, points, full_circle)

	# Vertical arcs every 45 degrees, and at the horizontal limits
	var azimuths := []
	var a := ceilf(h_min / (PI / 4)) * (PI / 4)
	while a <= h_max + 0.001:
		azimuths.append(a)
		a += PI / 4
	if not full_circle:
		azimuths.append_array([h_min, h_max])
	for azimuth in azimuths:
		var points := PackedVector3Array()
		for i in range(SEGMENTS / 4 + 1):
			points.append(direction(azimuth, lerpf(v_min, v_max, float(i) / (SEGMENTS / 4))) * r)
		add_polyline(lines, points)

	# Rays from the sensor to the corners of a partial scan
	if not full_circle:
		for corner in [Vector2(h_min, v_min), Vector2(h_min, v_max), Vector2(h_max, v_min), Vector2(h_max, v_max)]:
			lines.append(Vector3.ZERO)
			lines.append(direction(corner.x, corner.y) * r)

	# Sensor puck, with a tick pointing forward (azimuth 0)
	for y in [-0.04, 0.04]:
		add_circle(lines, Vector3(0, y, 0), Vector3.RIGHT, Vector3.BACK, 0.06, 16)
	lines.append(Vector3(0, 0, -0.06))
	lines.append(Vector3(0, 0, -0.12))
	commit(gizmo, lines)
