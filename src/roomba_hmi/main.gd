extends Control
## Roomba HMI: watch the camera, hold an arrow to drive, press Dock to send the robot home.

## Turn rate while ◀ or ▶ is held (rad/s)
@export var turn_speed: float = 1.5

@onready var _camera: TextureRect = %Camera
@onready var _status: Label = %Status
@onready var _message: Label = %Message
@onready var _speed: HSlider = %Speed
@onready var _forward: Button = %Forward
@onready var _back: Button = %Back
@onready var _left: Button = %Left
@onready var _right: Button = %Right

var _node: RosNode
var _cmd_vel_pub: RosPublisher
var _odom_sub: RosSubscriber
var _bumper_sub: RosSubscriber
var _camera_sub: RosSubscriber
var _dock_client: RosClient
var _drive_timer: RosTimer
var _cmd := RosGeometryMsgsTwist.new()
var _driving := false


func _ready() -> void:
	_node = RosNode.new()
	_node.init("roomba_hmi")
	_cmd_vel_pub = _node.create_publisher("/cmd_vel", "geometry_msgs/msg/Twist")
	_odom_sub = _node.create_subscription("/odom", "nav_msgs/msg/Odometry", _on_odom)
	_bumper_sub = _node.create_subscription("/bumper", "std_msgs/msg/Bool", _on_bumper)
	# The camera publishes best effort, so the subscription must be best effort too
	var sensor_qos := RosQoS.new()
	sensor_qos.set_reliability(RosQoS.BEST_EFFORT)
	_camera_sub = _node.create_subscription("/camera/image_raw", "sensor_msgs/msg/Image", _on_image, sensor_qos)
	_dock_client = _node.create_client("/roomba/dock", "std_srvs/srv/Trigger")
	_drive_timer = _node.create_timer(0.1, _drive)


## 10 Hz: publish while an arrow is held, then one stop when it's released
func _drive() -> void:
	var linear := float(_forward.button_pressed) - float(_back.button_pressed)
	var angular := float(_left.button_pressed) - float(_right.button_pressed)
	var driving := linear != 0.0 or angular != 0.0
	if not driving and not _driving:
		return # Idle: stay quiet, so other nodes can drive the robot too
	_driving = driving
	_cmd.linear.x = linear * _speed.value
	_cmd.angular.z = angular * turn_speed
	_cmd_vel_pub.publish(_cmd)


func _on_odom(msg: RosMsg) -> void:
	_status.text = "%.2f m/s   %.2f rad/s" % [msg.twist.twist.linear.x, msg.twist.twist.angular.z]


func _on_bumper(msg: RosMsg) -> void:
	_status.modulate = Color.RED if msg.data else Color.WHITE


## Turns the ROS image (rgba8 from the simulated camera) into a texture on screen
func _on_image(msg: RosMsg) -> void:
	var image := Image.create_from_data(msg.width, msg.height, false, Image.FORMAT_RGBA8, msg.data)
	_camera.texture = ImageTexture.create_from_image(image)


## Connected to the Dock button's "pressed" signal in the editor (Signals dock)
func _on_dock_pressed() -> void:
	_message.text = "Docking…"
	var request := _dock_client.async_send_request(_dock_client.create_request())
	var response: RosMsg = await request.completed
	_message.text = response.message
