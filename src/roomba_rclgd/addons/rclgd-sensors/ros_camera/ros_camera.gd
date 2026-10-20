@icon("res://addons/rclgd-sensors/icons/ros_camera.svg")
class_name RosCamera
extends RosSensor
## Pinhole camera publishing image_raw + camera_info, and optionally a pixel-aligned depth image.
## Images are in the optical frame "<frame>_optical" (z forward, x right, y down).

const DEPTH_EFFECT_CLASS = preload("res://addons/rclgd-sensors/ros_camera/depth_compositor.gd")

## Optical frame relative to the sensor frame: ROS optical axes (z forward, x right, y down)
const OPTICAL_TF = Transform3D(Basis(Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)), Vector3.ZERO)

@export_group("Sensor Settings")
@export var resolution: Vector2i = Vector2i(640, 480)
## Vertical field of view (degrees)
@export var fov: float = 75.0
@export var near: float = 0.05
@export var far: float = 150.0
@export_flags_3d_render var cull_mask: int = 1048575
## Also publish depth/image_raw: distance along the optical axis in meters (32FC1, 0 = no return)
@export var publish_depth: bool = false

@export_group("ROS 2 Settings")
## Capture rate (Hz), at most one capture per rendered frame
@export var publish_rate: float = 15.0

# --- Internal Nodes ---
var _viewport: SubViewport
var _camera: Camera3D

# --- ROS Components ---
var _camera_pub: RosPublisher
var _camera_info_pub: RosPublisher
var _depth_pub: RosPublisher
var _depth_info_pub: RosPublisher
var _color_queue: PublishQueue
var _depth_queue: PublishQueue

var _image_msg: RosSensorMsgsImage
var _info_msg: RosSensorMsgsCameraInfo
var _depth_msg: RosSensorMsgsImage
var _depth_info_msg: RosSensorMsgsCameraInfo
var _queued_stamp: RosMsg # Stamp of the capture waiting for the next drawn frame (null = none)

# --- Depth Capture (Compute Shader) Resources ---
var rd: RenderingDevice
var _depth_texture_rid: RID
var _depth_shader: RID
var _depth_pipeline: RID

func _sensor_ready() -> void:
	rd = RenderingServer.get_rendering_device()
	_setup_internal_nodes()

	var optical_frame := _frame_name() + "_optical"
	_tf_broadcaster.send_transform(OPTICAL_TF, optical_frame, _frame_name(), true)
	optical_frame = _node.resolve_frame(optical_frame)

	_camera_pub = _advertise("~/image_raw", "sensor_msgs/msg/Image")
	_camera_info_pub = _advertise("~/camera_info", "sensor_msgs/msg/CameraInfo")
	_image_msg = _make_image(optical_frame, "rgba8")
	_info_msg = _make_camera_info(optical_frame)
	_color_queue = _create_publish_queue(_publish.bind(_camera_pub, _image_msg, _camera_info_pub, _info_msg))

	if publish_depth:
		_setup_depth_capture()
		# Rendered by the same camera in the same pass: pixel-aligned, same frame and intrinsics
		_depth_pub = _advertise("~/depth/image_raw", "sensor_msgs/msg/Image")
		_depth_info_pub = _advertise("~/depth/camera_info", "sensor_msgs/msg/CameraInfo")
		_depth_msg = _make_image(optical_frame, "32FC1")
		_depth_info_msg = _make_camera_info(optical_frame)
		_depth_queue = _create_publish_queue(_publish.bind(_depth_pub, _depth_msg, _depth_info_pub, _depth_info_msg))

	_start_sampling(publish_rate)

func _setup_internal_nodes() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "RosViewport"
	_viewport.size = resolution
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# Optimizations
	_viewport.positional_shadow_atlas_size = 0
	_viewport.screen_space_aa = SubViewport.SCREEN_SPACE_AA_DISABLED
	_viewport.use_debanding = false
	_viewport.use_hdr_2d = false
	add_child(_viewport)

	_camera = Camera3D.new()
	_camera.name = "RosCamera3D"
	_camera.fov = fov
	_camera.near = near
	_camera.far = far
	_camera.cull_mask = cull_mask
	_viewport.add_child(_camera)

	# The camera lives in the viewport; this keeps it following the sensor
	var sync := RemoteTransform3D.new()
	sync.name = "CameraSync"
	add_child(sync)
	sync.remote_path = sync.get_path_to(_camera)

func _setup_depth_capture() -> void:
	# 1. Output texture (R32F: linear depth in meters along the optical axis, 0 = no return)
	var fmt: RDTextureFormat = RDTextureFormat.new()
	fmt.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	fmt.width = resolution.x
	fmt.height = resolution.y
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | \
					 RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | \
					 RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	_depth_texture_rid = rd.texture_create(fmt, RDTextureView.new())

	# 2. Compute shader that linearizes the hardware depth buffer for this camera's render pass
	var shader_file: RDShaderFile = load("res://addons/rclgd-sensors/ros_camera/DepthCapture.glsl")
	_depth_shader = rd.shader_create_from_spirv(shader_file.get_spirv())
	if _depth_shader.is_valid():
		_depth_pipeline = rd.compute_pipeline_create(_depth_shader)

	# 3. Compositor effect that dispatches the shader during the camera's own render pass
	var effect := DEPTH_EFFECT_CLASS.new()
	effect.target_tex = _depth_texture_rid
	effect.shader = _depth_shader
	effect.pipeline = _depth_pipeline
	var compositor := Compositor.new()
	compositor.compositor_effects = [effect]
	_camera.compositor = compositor

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and rd:
		if _depth_texture_rid.is_valid():
			rd.free_rid(_depth_texture_rid)
		if _depth_shader.is_valid():
			rd.free_rid(_depth_shader)

func _sample() -> void:
	if not is_visible_in_tree() or _queued_stamp != null:
		return
	_queued_stamp = _node.now()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if not RenderingServer.frame_post_draw.is_connected(_on_frame_drawn):
		RenderingServer.frame_post_draw.connect(_on_frame_drawn, CONNECT_ONE_SHOT)

# Readbacks take a few frames to arrive. A new capture doesn't wait for them: each readback
# carries its capture's stamp into the publish queue, which publishes in capture order.
func _on_frame_drawn() -> void:
	var stamp_ns := to_ns(_queued_stamp)
	_queued_stamp = null

	# Callbacks bind only plain values (see RosSensor.to_ns)
	var rid := RenderingServer.texture_get_rd_texture(_viewport.get_texture().get_rid())
	if rid.is_valid():
		rd.texture_get_data_async(rid, 0, _on_readback.bind(false, stamp_ns))
	if publish_depth and _depth_texture_rid.is_valid():
		rd.texture_get_data_async(_depth_texture_rid, 0, _on_readback.bind(true, stamp_ns))

func _on_readback(data: PackedByteArray, is_depth: bool, stamp_ns: int) -> void:
	if not data.is_empty():
		(_depth_queue if is_depth else _color_queue).push([stamp_ns, data])

# Copying image data into the message and publishing it takes ~0.5 ms per image, so it runs on
# the queue's thread. Each queue publishes one capture at a time, so it can reuse its messages.
func _publish(stamp_ns: int, data: PackedByteArray, image_pub: RosPublisher, image_msg: RosSensorMsgsImage,
		info_pub: RosPublisher, info_msg: RosSensorMsgsCameraInfo) -> void:
	write_stamp(image_msg.header, stamp_ns)
	image_msg.data = data
	write_stamp(info_msg.header, stamp_ns)
	image_pub.publish(image_msg)
	info_pub.publish(info_msg)

func _make_image(optical_frame: String, encoding: String) -> RosSensorMsgsImage:
	var msg := RosSensorMsgsImage.new()
	msg.header.frame_id = optical_frame
	msg.height = resolution.y
	msg.width = resolution.x
	msg.encoding = encoding
	msg.step = resolution.x * 4 # Both rgba8 and 32FC1 are 4 bytes per pixel
	return msg

func _make_camera_info(optical_frame: String) -> RosSensorMsgsCameraInfo:
	var msg := RosSensorMsgsCameraInfo.new()
	msg.header.frame_id = optical_frame
	msg.width = resolution.x
	msg.height = resolution.y
	msg.distortion_model = "plumb_bob"
	msg.d = PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0])

	# Square pixels; Camera3D.fov is vertical (keep_aspect = KEEP_HEIGHT)
	var fy := resolution.y / (2.0 * tan(deg_to_rad(fov) / 2.0))
	var fx := fy
	var cx := resolution.x / 2.0
	var cy := resolution.y / 2.0
	msg.k = PackedFloat64Array([fx, 0.0, cx, 0.0, fy, cy, 0.0, 0.0, 1.0])
	msg.r = PackedFloat64Array([1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0])
	msg.p = PackedFloat64Array([fx, 0.0, cx, 0.0, 0.0, fy, cy, 0.0, 0.0, 0.0, 1.0, 0.0])
	return msg
