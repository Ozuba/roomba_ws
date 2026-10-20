@tool
extends "res://addons/rclgd-sensors/sensor_gizmo.gd"
## Field of view for RosFisheyeCamera. Circular fisheye: a spherical cap of half-angle fov/2
## around -Z. Equirectangular: the full sphere, as FisheyeStitch.glsl renders it.

const SEGMENTS: int = 48
const EQUIRECTANGULAR: int = 1 # RosFisheyeCamera.ProjectionType.EQUIRECTANGULAR

func _init() -> void:
	create_material("main", Color(0.5, 0.8, 1.0))

func _get_gizmo_name() -> String:
	return "RosFisheyeCamera"

func _has_gizmo(node: Node3D) -> bool:
	return node is RosFisheyeCamera

func _draw_sensor(gizmo: EditorNode3DGizmo, node: Node3D) -> void:
	var fov := deg_to_rad(clampf(node.fov, 1.0, 360.0))
	var lines := PackedVector3Array()

	if node.projection_type == EQUIRECTANGULAR:
		# FisheyeStitch.glsl always renders the full sphere here; fov is ignored
		for lat in [-PI / 3, -PI / 6, 0.0, PI / 6, PI / 3]:
			var points := PackedVector3Array()
			for i in range(SEGMENTS):
				points.append(direction(TAU * i / SEGMENTS, lat) * DISPLAY_RANGE)
			add_polyline(lines, points, true)
		for k in range(8):
			var points := PackedVector3Array()
			for i in range(SEGMENTS / 2 + 1):
				points.append(direction(TAU * k / 8, lerpf(-PI / 2, PI / 2, float(i) / (SEGMENTS / 2))) * DISPLAY_RANGE)
			add_polyline(lines, points)
		# Ray to the image center (longitude 0)
		lines.append(Vector3.ZERO)
		lines.append(Vector3.FORWARD * DISPLAY_RANGE)
	else:
		var theta_max := fov * 0.5
		# Rim of the cap plus an inner ring at half the angle
		for theta in [theta_max, theta_max * 0.5]:
			var points := PackedVector3Array()
			for i in range(SEGMENTS):
				points.append(_cap_point(theta, TAU * i / SEGMENTS))
			add_polyline(lines, points, true)
		# Meridians from the optical axis to the rim, and rays from the lens to the rim
		for k in range(8):
			var phi := TAU * k / 8
			var points := PackedVector3Array()
			for i in range(SEGMENTS / 2 + 1):
				points.append(_cap_point(theta_max * i / (SEGMENTS / 2), phi))
			add_polyline(lines, points)
			if k % 2 == 0:
				lines.append(Vector3.ZERO)
				lines.append(_cap_point(theta_max, phi))

	# Up marker above the optical axis
	var up_base := Vector3(0, 0, -DISPLAY_RANGE * 0.25)
	add_polyline(lines, PackedVector3Array([
		up_base + Vector3(-0.05, 0.1, 0), up_base + Vector3(0, 0.16, 0), up_base + Vector3(0.05, 0.1, 0)
	]), true)
	commit(gizmo, lines)

## Point on the display sphere at angle `theta` from the -Z optical axis, rotated `phi` around it.
func _cap_point(theta: float, phi: float) -> Vector3:
	return Vector3(sin(theta) * cos(phi), sin(theta) * sin(phi), -cos(theta)) * DISPLAY_RANGE
