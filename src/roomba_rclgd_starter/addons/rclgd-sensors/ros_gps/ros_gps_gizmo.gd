@tool
extends "res://addons/rclgd-sensors/sensor_gizmo.gd"
## RosGps: an antenna (base disc, mast, patch) with a ring showing the horizontal noise `position_std`.

const MAST_HEIGHT: float = 0.15

func _init() -> void:
	create_material("main", Color(0.3, 1.0, 0.5))
	create_material("noise", Color(0.3, 1.0, 0.5, 0.35))

func _get_gizmo_name() -> String:
	return "RosGps"

func _has_gizmo(node: Node3D) -> bool:
	return node is RosGps

func _draw_sensor(gizmo: EditorNode3DGizmo, node: Node3D) -> void:

	var lines := PackedVector3Array()
	add_circle(lines, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK, 0.05, 16)
	lines.append(Vector3.ZERO)
	lines.append(Vector3.UP * MAST_HEIGHT)
	add_circle(lines, Vector3.UP * MAST_HEIGHT, Vector3.RIGHT, Vector3.BACK, 0.03, 12)
	commit(gizmo, lines)

	if node.position_std > 0.0:
		var noise := PackedVector3Array()
		add_circle(noise, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK, node.position_std, 48)
		# Only drawn, not clickable: the ring can be meters wide
		gizmo.add_lines(noise, get_material("noise", gizmo))
