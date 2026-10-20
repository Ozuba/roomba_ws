extends Node3D
## Workshop main scene: the house, the Roomba and a camera. Press C to switch camera views.

enum CameraMode { OVERVIEW, TOP_DOWN, FOLLOW }
const MODE_NAMES: Array[String] = ["Overview", "Top-down", "Follow"]

@export var camera_mode: CameraMode = CameraMode.OVERVIEW

@onready var _roomba: Roomba = $Roomba
@onready var _camera: Camera3D = $Camera
@onready var _hud: Label = $Hud/Label


func _ready() -> void:
	_apply_camera_mode()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		camera_mode = ((camera_mode + 1) % MODE_NAMES.size()) as CameraMode
		_apply_camera_mode()


func _apply_camera_mode() -> void:
	match camera_mode:
		CameraMode.OVERVIEW:
			_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			_camera.fov = 50.0
			_camera.look_at_from_position(Vector3(4.0, 6.4, 9.6), Vector3(4.0, 0.0, 3.1))
		CameraMode.TOP_DOWN:
			_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			_camera.size = 6.8
			_camera.look_at_from_position(Vector3(4.0, 10.0, 3.0), Vector3(4.0, 0.0, 3.0), Vector3.FORWARD)
		CameraMode.FOLLOW:
			_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			_camera.fov = 65.0
			_follow(1.0)


func _process(delta: float) -> void:
	if camera_mode == CameraMode.FOLLOW:
		_follow(1.0 - exp(-4.0 * delta))
	_hud.text = "Camera: %s   [C] switch\nlinear %+.2f m/s   angular %+.2f rad/s   bumper %s\n%d FPS" % [
		MODE_NAMES[camera_mode], _roomba.linear_speed, _roomba.angular_speed,
		"PRESSED" if _roomba.bumper_pressed else "released", Engine.get_frames_per_second()]


## Chase camera behind and above the robot; weight 1 snaps, smaller values smooth the motion
func _follow(weight: float) -> void:
	var target := _roomba.global_transform * Vector3(0.0, 0.6, 0.95)
	var eye := _camera.global_position.lerp(target, weight)
	_camera.look_at_from_position(eye, _roomba.global_position + Vector3(0, 0.08, 0))
