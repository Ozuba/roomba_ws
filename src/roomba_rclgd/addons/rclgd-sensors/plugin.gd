@tool
extends EditorPlugin

const GIZMO_SCRIPTS = [
	preload("res://addons/rclgd-sensors/ros_camera/ros_camera_gizmo.gd"),
	preload("res://addons/rclgd-sensors/ros_fisheye_camera/ros_fisheye_camera_gizmo.gd"),
	preload("res://addons/rclgd-sensors/ros_lidar/ros_lidar_gizmo.gd"),
	preload("res://addons/rclgd-sensors/ros_lidar_2d/ros_lidar_2d_gizmo.gd"),
	preload("res://addons/rclgd-sensors/ros_imu/ros_imu_gizmo.gd"),
	preload("res://addons/rclgd-sensors/ros_gps/ros_gps_gizmo.gd"),
]

var _gizmo_plugins: Array[EditorNode3DGizmoPlugin] = []

func _enter_tree() -> void:
	for script in GIZMO_SCRIPTS:
		var gizmo_plugin: EditorNode3DGizmoPlugin = script.new()
		add_node_3d_gizmo_plugin(gizmo_plugin)
		_gizmo_plugins.append(gizmo_plugin)

	# Sensor scripts are not @tool, so their setters don't run in the editor.
	# Redraw the gizmo whenever a property is edited in the inspector instead.
	EditorInterface.get_inspector().property_edited.connect(_on_property_edited)

func _exit_tree() -> void:
	EditorInterface.get_inspector().property_edited.disconnect(_on_property_edited)
	for gizmo_plugin in _gizmo_plugins:
		remove_node_3d_gizmo_plugin(gizmo_plugin)
	_gizmo_plugins.clear()

func _on_property_edited(_property: String) -> void:
	var edited = EditorInterface.get_inspector().get_edited_object()
	if edited is Node3D:
		edited.update_gizmos()
