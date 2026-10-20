@tool
extends "res://addons/rclgd-sensors/sensor_gizmo.gd"
## RosImu: a small box with its local X (red), Y (green) and Z (blue) axes.

const BOX_SIZE: float = 0.08
const AXIS_LENGTH: float = 0.2

func _init() -> void:
	create_material("main", Color(1.0, 0.85, 0.3))
	create_material("x", Color(1.0, 0.3, 0.3))
	create_material("y", Color(0.4, 1.0, 0.4))
	create_material("z", Color(0.35, 0.55, 1.0))

func _get_gizmo_name() -> String:
	return "RosImu"

func _has_gizmo(node: Node3D) -> bool:
	return node is RosImu

func _draw_sensor(gizmo: EditorNode3DGizmo, _node: Node3D) -> void:
	var lines := PackedVector3Array()
	add_box(lines, Vector3.ZERO, Vector3.ONE * BOX_SIZE)
	commit(gizmo, lines)

	for axis in [["x", Vector3.RIGHT], ["y", Vector3.UP], ["z", Vector3.BACK]]:
		var dir: Vector3 = axis[1]
		var tip := dir * AXIS_LENGTH
		# Arrowhead fins, perpendicular to the axis
		var side := dir.cross(Vector3.UP if dir != Vector3.UP else Vector3.RIGHT) * 0.02
		commit(gizmo, PackedVector3Array([
			Vector3.ZERO, tip,
			tip, tip - dir * 0.04 + side,
			tip, tip - dir * 0.04 - side,
		]), axis[0])
