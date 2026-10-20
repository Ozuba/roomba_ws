@icon("res://addons/rclgd-sensors/icons/ros_fisheye_camera.svg")
class_name RosFisheyeCamera
extends RosSensor
## Wide-angle camera rendered as a cube map and stitched into a circular fisheye (equidistant
## model) or an equirectangular image. Images are in the optical frame "<frame>_optical".

enum ProjectionType {
	CIRCULAR_FISHEYE,
	EQUIRECTANGULAR
}

# --- Configuration ---
@export_group("Sensor Settings")
@export var projection_type: ProjectionType = ProjectionType.CIRCULAR_FISHEYE:
	set(val):
		projection_type = val
		_update_cached_templates()

@export var resolution: Vector2i = Vector2i(640, 480):
	set(val):
		resolution = val
		_update_cached_templates()

@export var fov: float = 180.0:
	set(val):
		fov = val
		_update_cached_templates()

@export var face_resolution: int = 512:
	set(val):
		face_resolution = val
		for vp in _viewports:
			vp.size = Vector2i(face_resolution, face_resolution)

@export var near: float = 0.05:
	set(val):
		near = val
		for cam in _cameras:
			cam.near = near

@export var far: float = 150.0:
	set(val):
		far = val
		for cam in _cameras:
			cam.far = far

@export_flags_3d_render var cull_mask: int = 1048575:
	set(val):
		cull_mask = val
		for cam in _cameras:
			cam.cull_mask = cull_mask

@export_group("Calibration (Sim2Real)")
@export var use_custom_calibration: bool = false:
	set(val):
		use_custom_calibration = val
		_update_cached_templates()

@export var custom_fx: float = 240.0:
	set(val):
		custom_fx = val
		_update_cached_templates()

@export var custom_fy: float = 240.0:
	set(val):
		custom_fy = val
		_update_cached_templates()

@export var custom_cx: float = 320.0:
	set(val):
		custom_cx = val
		_update_cached_templates()

@export var custom_cy: float = 240.0:
	set(val):
		custom_cy = val
		_update_cached_templates()

@export var k1: float = 0.0:
	set(val):
		k1 = val
		_update_cached_templates()

@export var k2: float = 0.0:
	set(val):
		k2 = val
		_update_cached_templates()

@export var k3: float = 0.0:
	set(val):
		k3 = val
		_update_cached_templates()

@export var k4: float = 0.0:
	set(val):
		k4 = val
		_update_cached_templates()

@export_group("ROS 2 Settings")
## Capture rate (Hz), at most one capture per rendered frame
@export var publish_rate: float = 15.0

# --- Internal Nodes ---
var _viewports: Array[SubViewport] = []
var _cameras: Array[Camera3D] = []
var _remote_syncs: Array[RemoteTransform3D] = []

# --- ROS Components ---
var _camera_pub: RosPublisher
var _camera_info_pub: RosPublisher

# --- Internal Variables ---
var _cached_image_msg: RosSensorMsgsImage
var _cached_info_msg: RosSensorMsgsCameraInfo
var rd: RenderingDevice
var _resolved_optical_frame: String
var _queued_stamp: RosMsg # Stamp of the capture waiting for the next drawn frame (null = none)
var _publish_queue: PublishQueue

# --- Compute Shader Variables ---
var _compute_shader_rid: RID
var _pipeline_rid: RID
var _output_texture_rid: RID
var _output_texture_size: Vector2i = Vector2i.ZERO
var _sampler_rid: RID
var _params_buffer_rid: RID

func _sensor_ready() -> void:
	rd = RenderingServer.get_rendering_device()
	_setup_rendering_pipeline()

	var optical_frame := _frame_name() + "_optical"
	_tf_broadcaster.send_transform(RosCamera.OPTICAL_TF, optical_frame, _frame_name(), true)
	_resolved_optical_frame = _node.resolve_frame(optical_frame)

	_camera_pub = _advertise("~/image_raw", "sensor_msgs/msg/Image")
	_camera_info_pub = _advertise("~/camera_info", "sensor_msgs/msg/CameraInfo")
	_cache_message_templates()
	_publish_queue = _create_publish_queue(_publish)
	_start_sampling(publish_rate)

func _setup_rendering_pipeline() -> void:
	# Rotations for the 6 faces (+X, -X, +Y, -Y, +Z, -Z)
	var rotations = [
		Vector3(0, deg_to_rad(-90), 0),  # +X (Right)
		Vector3(0, deg_to_rad(90), 0),   # -X (Left)
		Vector3(deg_to_rad(90), 0, 0),   # +Y (Up)
		Vector3(deg_to_rad(-90), 0, 0),  # -Y (Down)
		Vector3(0, deg_to_rad(180), 0),  # +Z (Back)
		Vector3(0, 0, 0),                # -Z (Forward)
	]
	
	var names = ["Right", "Left", "Up", "Down", "Back", "Forward"]
	
	for i in range(6):
		# Create SubViewport
		var vp = SubViewport.new()
		vp.name = "FisheyeViewport_" + names[i]
		vp.size = Vector2i(face_resolution, face_resolution)
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		
		# Optimizations
		vp.positional_shadow_atlas_size = 0
		vp.screen_space_aa = SubViewport.SCREEN_SPACE_AA_DISABLED
		vp.use_debanding = false
		vp.use_hdr_2d = false
		
		add_child(vp)
		_viewports.append(vp)
		
		# Create Camera3D
		var cam = Camera3D.new()
		cam.name = "FisheyeCamera_" + names[i]
		cam.fov = 90.0
		cam.near = near
		cam.far = far
		cam.cull_mask = cull_mask
		vp.add_child(cam)
		_cameras.append(cam)
		
		# Setup RemoteTransform3D to sync the camera to THIS node
		var sync = RemoteTransform3D.new()
		sync.name = "CameraSync_" + names[i]
		add_child(sync)
		sync.remote_path = sync.get_path_to(cam)
		sync.rotation = rotations[i]
		_remote_syncs.append(sync)

func _sample() -> void:
	if not is_visible_in_tree() or _queued_stamp != null: return

	_queued_stamp = _node.now()
	for vp in _viewports:
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		
	if not RenderingServer.frame_post_draw.is_connected(_on_frame_drawn):
		RenderingServer.frame_post_draw.connect(_on_frame_drawn, CONNECT_ONE_SHOT)

# Readbacks take a few frames to arrive. A new capture doesn't wait for them: each readback
# carries its capture's stamp into the publish queue, which publishes in capture order.
func _on_frame_drawn() -> void:
	var stamp_ns := to_ns(_queued_stamp) # Callbacks bind only plain values (see RosSensor.to_ns)
	_queued_stamp = null
	_run_compute_shader(stamp_ns)

func _on_data_received(data: PackedByteArray, stamp_ns: int) -> void:
	if not data.is_empty():
		# Hand over the current templates: the property setters may replace them meanwhile
		_publish_queue.push([stamp_ns, data, _cached_image_msg, _cached_info_msg])

# Copying image data into the message and publishing it is expensive, so it runs on the
# queue's thread. The queue publishes one capture at a time, so it can reuse the templates.
func _publish(stamp_ns: int, data: PackedByteArray, image_msg: RosSensorMsgsImage,
		info_msg: RosSensorMsgsCameraInfo) -> void:
	write_stamp(image_msg.header, stamp_ns)
	image_msg.data = data
	write_stamp(info_msg.header, stamp_ns)
	_camera_pub.publish(image_msg)
	_camera_info_pub.publish(info_msg)

func _update_cached_templates() -> void:
	if _node:
		_cache_message_templates()

func _cache_message_templates() -> void:
	_cached_image_msg = RosSensorMsgsImage.new()
	_cached_image_msg.height = resolution.y
	_cached_image_msg.width = resolution.x
	_cached_image_msg.encoding = "rgba8"
	_cached_image_msg.step = resolution.x * 4
	_cached_image_msg.header.frame_id = _resolved_optical_frame
	
	_cached_info_msg = RosSensorMsgsCameraInfo.new()
	_cached_info_msg.header.frame_id = _resolved_optical_frame
	_cached_info_msg.width = resolution.x
	_cached_info_msg.height = resolution.y
	
	var fx_val = custom_fx
	var fy_val = custom_fy
	var cx_val = custom_cx
	var cy_val = custom_cy
	var d_val = PackedFloat64Array([k1, k2, k3, k4])
	
	if projection_type == ProjectionType.CIRCULAR_FISHEYE:
		_cached_info_msg.distortion_model = "equidistant"
		if not use_custom_calibration:
			var max_theta = deg_to_rad(fov / 2.0)
			var radius = resolution.y / 2.0 # The shader fits the image circle to the height
			fx_val = radius / max_theta
			fy_val = fx_val
			cx_val = resolution.x / 2.0
			cy_val = resolution.y / 2.0
			d_val = PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
	else:
		_cached_info_msg.distortion_model = "equirectangular"
		if not use_custom_calibration:
			fx_val = 0.0
			fy_val = 0.0
			cx_val = 0.0
			cy_val = 0.0
			d_val = PackedFloat64Array([])
			
	_cached_info_msg.k = PackedFloat64Array([fx_val, 0.0, cx_val, 0.0, fy_val, cy_val, 0.0, 0.0, 1.0])
	_cached_info_msg.r = PackedFloat64Array([1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0])
	_cached_info_msg.p = PackedFloat64Array([fx_val, 0.0, cx_val, 0.0, 0.0, fy_val, cy_val, 0.0, 0.0, 0.0, 1.0, 0.0])
	_cached_info_msg.d = d_val

func _exit_tree() -> void:
	if rd:
		if _sampler_rid.is_valid():
			rd.free_rid(_sampler_rid)
		if _params_buffer_rid.is_valid():
			rd.free_rid(_params_buffer_rid)
		if _output_texture_rid.is_valid():
			rd.free_rid(_output_texture_rid)
		if _pipeline_rid.is_valid():
			rd.free_rid(_pipeline_rid)
		if _compute_shader_rid.is_valid():
			rd.free_rid(_compute_shader_rid)

func _run_compute_shader(stamp_ns: int) -> void:
	if not _compute_shader_rid.is_valid():
		_init_compute_shader()
		if not _compute_shader_rid.is_valid():
			return
			
	_ensure_output_texture()
	if not _output_texture_rid.is_valid():
		return
		
	var face_rids: Array[RID] = []
	for i in range(6):
		var tex = _viewports[i].get_texture()
		var face_rid = RenderingServer.texture_get_rd_texture(tex.get_rid())
		if not face_rid.is_valid():
			return
		face_rids.append(face_rid)
		
	# Pack standard UBO parameters (48 bytes, 12 float fields)
	var max_theta = deg_to_rad(fov / 2.0)
	var aspect = float(resolution.x) / float(resolution.y)
	
	# Intrinsic calibration falls back to ideal parameters if use_custom_calibration is disabled
	var fx_val = custom_fx
	var fy_val = custom_fy
	var cx_val = custom_cx
	var cy_val = custom_cy
	var k1_val = k1
	var k2_val = k2
	var k3_val = k3
	var k4_val = k4
	
	if not use_custom_calibration:
		var radius = resolution.y / 2.0 # The shader fits the image circle to the height
		fx_val = radius / max_theta
		fy_val = fx_val
		cx_val = resolution.x / 2.0
		cy_val = resolution.y / 2.0
		k1_val = 0.0
		k2_val = 0.0
		k3_val = 0.0
		k4_val = 0.0
		
	var params_array = PackedFloat32Array([
		float(projection_type),
		max_theta,
		aspect,
		1.0 if use_custom_calibration else 0.0,
		
		fx_val,
		fy_val,
		cx_val,
		cy_val,
		
		k1_val,
		k2_val,
		k3_val,
		k4_val
	])
	var params_bytes = params_array.to_byte_array()
	
	RenderingServer.call_on_render_thread(_dispatch_stitching.bind(face_rids, params_bytes, stamp_ns))

func _dispatch_stitching(face_rids: Array[RID], params_bytes: PackedByteArray, stamp_ns: int) -> void:
	if not _compute_shader_rid.is_valid() or not _pipeline_rid.is_valid() or not _output_texture_rid.is_valid():
		return
		
	if not _sampler_rid.is_valid():
		var sampler_state = RDSamplerState.new()
		sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
		sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
		_sampler_rid = rd.sampler_create(sampler_state)
		
	# Bind textures to uniforms matching GLSL layout bindings:
	# Binding 0: face_forward (index 5)
	# Binding 1: face_left (index 1)
	# Binding 2: face_right (index 0)
	# Binding 3: face_up (index 2)
	# Binding 4: face_down (index 3)
	# Binding 5: face_back (index 4)
	var mapping = [5, 1, 0, 2, 3, 4]
	var uniforms: Array[RDUniform] = []
	for binding in range(6):
		var u = RDUniform.new()
		u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		u.binding = binding
		u.add_id(_sampler_rid)
		u.add_id(face_rids[mapping[binding]])
		uniforms.append(u)
		
	var output_uniform = RDUniform.new()
	output_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	output_uniform.binding = 6
	output_uniform.add_id(_output_texture_rid)
	uniforms.append(output_uniform)
	
	if not _params_buffer_rid.is_valid():
		_params_buffer_rid = rd.uniform_buffer_create(params_bytes.size(), params_bytes)
	else:
		rd.buffer_update(_params_buffer_rid, 0, params_bytes.size(), params_bytes)
		
	var params_uniform = RDUniform.new()
	params_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	params_uniform.binding = 7
	params_uniform.add_id(_params_buffer_rid)
	uniforms.append(params_uniform)
	
	var uniform_set = rd.uniform_set_create(uniforms, _compute_shader_rid, 0)
	
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, _pipeline_rid)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	var x_groups = int(ceil(float(resolution.x) / 8.0))
	var y_groups = int(ceil(float(resolution.y) / 8.0))
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	rd.compute_list_end()
	# A new set is built every capture; RenderingDevice defers the free until the GPU is done with it
	rd.free_rid(uniform_set)
	
	rd.texture_get_data_async(_output_texture_rid, 0, _on_data_received.bind(stamp_ns))

func _init_compute_shader() -> void:
	var shader_file = load("res://addons/rclgd-sensors/ros_fisheye_camera/FisheyeStitch.glsl")
	var shader_spirv = shader_file.get_spirv()
	if shader_spirv.compile_error_compute != "":
		push_error("Compute shader compilation error: " + shader_spirv.compile_error_compute)
		return
	_compute_shader_rid = rd.shader_create_from_spirv(shader_spirv)
	if _compute_shader_rid.is_valid():
		_pipeline_rid = rd.compute_pipeline_create(_compute_shader_rid)

func _ensure_output_texture() -> void:
	if _output_texture_rid.is_valid() and _output_texture_size == resolution:
		return
		
	if _output_texture_rid.is_valid():
		rd.free_rid(_output_texture_rid)
		_output_texture_rid = RID()
		
	var tf = RDTextureFormat.new()
	tf.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	tf.width = resolution.x
	tf.height = resolution.y
	tf.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CPU_READ_BIT
	
	_output_texture_rid = rd.texture_create(tf, RDTextureView.new(), [])
	_output_texture_size = resolution
