class_name Roomba
extends RigidBody3D
## A small differential-drive vacuum robot, simulated with plain Godot physics.
##
## Call drive(linear, angular) and the body follows those speeds every physics tick, sliding
## along whatever it touches. The front bumper reports contacts through bumper_changed.
## Nothing here knows about ROS yet: that is what you add during the workshop.

## Emitted when the front bumper is pressed or released
signal bumper_changed(pressed: bool)

@export_group("Drive")
## Forward speed limit (m/s)
@export var max_linear_speed: float = 0.5
## Turn rate limit (rad/s)
@export var max_angular_speed: float = 2.5
## How fast the wheels reach the commanded speeds (m/s² and rad/s²)
@export var linear_acceleration: float = 1.5
@export var angular_acceleration: float = 8.0

## Current wheel speeds after the acceleration ramp (m/s, rad/s; positive = forward, left)
var linear_speed: float = 0.0
var angular_speed: float = 0.0
## True while something is pressing the front half of the bumper
var bumper_pressed: bool = false

var _target_linear: float = 0.0
var _target_angular: float = 0.0
var _teleport_target = null # Transform3D waiting to be applied in the next physics step

@onready var _led: MeshInstance3D = $Visuals/Led
@onready var _side_brush: Node3D = $Visuals/SideBrush


## Sets the commanded speeds: linear in m/s (forward), angular in rad/s (counterclockwise
## seen from above). Both are clamped to the limits.
func drive(linear: float, angular: float) -> void:
	_target_linear = clampf(linear, -max_linear_speed, max_linear_speed)
	_target_angular = clampf(angular, -max_angular_speed, max_angular_speed)


func stop() -> void:
	drive(0.0, 0.0)


## Moves the robot to a global transform (e.g. the dock), stopped
func teleport(target: Transform3D) -> void:
	stop()
	_teleport_target = target


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _teleport_target != null:
		state.transform = _teleport_target
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		linear_speed = 0.0
		angular_speed = 0.0
		_teleport_target = null
		return

	# Differential drive: the wheels set the velocity along the robot's heading and the yaw
	# rate. Gravity keeps acting on the vertical component.
	linear_speed = move_toward(linear_speed, _target_linear, linear_acceleration * state.step)
	angular_speed = move_toward(angular_speed, _target_angular, angular_acceleration * state.step)
	var forward := -state.transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	state.linear_velocity = forward * linear_speed + Vector3.UP * state.linear_velocity.y
	state.angular_velocity = Vector3.UP * angular_speed

	_update_bumper(state)


## The bumper covers the front half of the robot. Contacts with the floor (normals pointing
## up) don't count.
func _update_bumper(state: PhysicsDirectBodyState3D) -> void:
	var pressed := false
	for i in state.get_contact_count():
		if absf(state.get_contact_local_normal(i).y) > 0.5:
			continue
		var contact := state.transform.affine_inverse() * state.get_contact_local_position(i)
		if contact.z < 0.0: # Forward is -Z
			pressed = true
			break
	if pressed != bumper_pressed:
		bumper_pressed = pressed
		bumper_changed.emit(pressed)


func _process(delta: float) -> void:
	# Cosmetics: spin the side brush while moving, LED shows the state
	var moving := absf(linear_speed) > 0.01 or absf(angular_speed) > 0.01
	if moving:
		_side_brush.rotate_y(-18.0 * delta)
	var led_mat := _led.material_override as StandardMaterial3D
	var color := Color(1.0, 0.2, 0.15) if bumper_pressed else (Color(0.2, 0.6, 1.0) if moving else Color(0.2, 1.0, 0.45))
	led_mat.albedo_color = color
	led_mat.emission = color
