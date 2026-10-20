@icon("res://addons/rclgd-sensors/icons/ros_lidar.svg")
class_name RosLidar
extends RosSensor
## Spinning lidar rendered as a cube map. Publishes an organized PointCloud2: one row per beam
## (ring 0 = lowest), one column per azimuth step, with x, y, z, intensity and ring fields.
## Beams without a return are NaN, so the cloud is not dense.

const FACE_CAPTURE_EFFECT_CLASS = preload("res://addons/rclgd-sensors/ros_lidar/lidar_compositor.gd")
## Bytes per point: x, y, z, intensity (float32) + ring (uint16) + 2 bytes padding, as LidarStitch.glsl writes them
const POINT_STEP: int = 20

# --- Configuration ---
@export_group("Sensor Settings")
@export var horizontal_resolution: int = 1024
@export var vertical_resolution: int = 64
@export var vertical_fov_min: float = -45.0 # Degrees
@export var vertical_fov_max: float = 45.0 # Degrees
@export var horizontal_fov_min: float = -180.0 # Degrees
@export var horizontal_fov_max: float = 180.0 # Degrees
@export var min_range: float = 0.1 # Meters
@export var max_range: float = 100.0 # Meters
@export var noise_std_dev: float = 0.005 # Standard deviation for Gaussian noise in meters
@export var face_resolution: int = 256 # Resolution of each cubemap face. Set to 0 to auto-calculate (horizontal_resolution / 4)
@export_flags_3d_render var cull_mask: int = 1048575 # 3D Render layers to capture

@export_group("ROS 2 Settings")
## Scan rate (Hz), at most one scan per rendered frame
@export var publish_rate: float = 10.0
@export var lidar_topic: String = "~/lidar"

# --- Internal Nodes ---
var _viewports: Array[SubViewport] = []
var _cameras: Array[Camera3D] = []
var _remote_syncs: Array[RemoteTransform3D] = []

# --- Resource Retention (Crucial for RIDs) ---
var _compositors: Array[Compositor] = []
var _effects: Array[LidarFaceCompositorEffect] = []

# --- ROS Components ---
var _lidar_pub: RosPublisher

# --- Rendering Components ---
var _rd: RenderingDevice
var _face_textures: Array[RID] = []
var _points_buffer: RID # Stitched scan, laid out as the PointCloud2 data
var _queued_stamp: RosMsg # Stamp of the scan waiting for the next drawn frame (null = none)
var _publish_queue: PublishQueue
var _cached_msg: RosSensorMsgsPointCloud2

var _stitch_shader: RID
var _stitch_pipeline: RID
var _face_capture_shader: RID
var _face_capture_pipeline: RID
var _params_buffer: RID
var _stitch_uniform_set: RID
var _params_float_array: PackedFloat32Array = PackedFloat32Array()
var _lidar_environment: Environment
var _actual_face_resolution: int = 256

func _sensor_ready() -> void:
	# 1. Setup hardware rendering
	_rd = RenderingServer.get_rendering_device()
	_params_float_array.resize(300)
	
	_actual_face_resolution = face_resolution
	if _actual_face_resolution <= 0:
		_actual_face_resolution = nearest_po2(horizontal_resolution / 4)
		_actual_face_resolution = clamp(_actual_face_resolution, 64, 1024)
		
	_create_textures()
	_init_shaders()
	_init_render_resources()
	
	# 2. Pipeline hierarchy (Viewports and cameras)
	_setup_rendering_pipeline()

	# 3. ROS 2
	_lidar_pub = _advertise(lidar_topic, "sensor_msgs/msg/PointCloud2")
	_prepare_msg_template()
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

	# Create a shared Environment for all lidar cameras with all post-processing disabled for max performance
	_lidar_environment = Environment.new()
	_lidar_environment.background_mode = Environment.BG_CLEAR_COLOR
	_lidar_environment.ssao_enabled = false
	_lidar_environment.ssil_enabled = false
	_lidar_environment.ssr_enabled = false
	_lidar_environment.glow_enabled = false
	_lidar_environment.sdfgi_enabled = false
	_lidar_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR

	for i in range(6):
		# Create SubViewport
		var vp = SubViewport.new()
		vp.name = "LidarViewport_" + names[i]
		vp.size = Vector2i(_actual_face_resolution, _actual_face_resolution)
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		
		# Optimizations: Disable redundant rendering features for depth/color capturing
		vp.positional_shadow_atlas_size = 0
		vp.screen_space_aa = SubViewport.SCREEN_SPACE_AA_DISABLED
		vp.use_debanding = false
		vp.use_occlusion_culling = true
		vp.msaa_3d = SubViewport.MSAA_DISABLED
		vp.msaa_2d = SubViewport.MSAA_DISABLED
		vp.use_hdr_2d = false
		
		add_child(vp)
		_viewports.append(vp)
		
		# Create Camera3D
		var cam = Camera3D.new()
		cam.name = "LidarCamera_" + names[i]
		cam.fov = 90.0
		cam.near = min_range
		cam.far = max_range
		cam.environment = _lidar_environment
		cam.cull_mask = cull_mask
		vp.add_child(cam)
		_cameras.append(cam)
		
		# Setup Compositor Effect on Camera
		var effect = FACE_CAPTURE_EFFECT_CLASS.new()
		effect.target_tex = _face_textures[i]
		effect.texture_size = Vector2(_actual_face_resolution, _actual_face_resolution)
		effect.shader = _face_capture_shader
		effect.pipeline = _face_capture_pipeline
		_effects.append(effect)
		
		var comp = Compositor.new()
		comp.compositor_effects = [effect]
		_compositors.append(comp)
		cam.compositor = comp

		# Setup RemoteTransform3D to sync the camera to THIS node
		var sync = RemoteTransform3D.new()
		sync.name = "LidarSync_" + names[i]
		add_child(sync)
		sync.remote_path = sync.get_path_to(cam)
		sync.rotation = rotations[i]
		_remote_syncs.append(sync)

func _create_textures() -> void:
	# 6 face textures (RGBA32F: R = depth, G = intensity)
	for i in range(6):
		var fmt : RDTextureFormat = RDTextureFormat.new()
		fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT 
		fmt.width = _actual_face_resolution
		fmt.height = _actual_face_resolution
		fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | \
						 RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | \
						 RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
		_face_textures.append(_rd.texture_create(fmt, RDTextureView.new()))
		
	# Output buffer: the scan as PointCloud2 data, so it is published without conversion
	_points_buffer = _rd.storage_buffer_create(horizontal_resolution * vertical_resolution * POINT_STEP)

func _init_shaders() -> void:
	# 1. Stitching Shader
	var stitch_file: RDShaderFile = load("res://addons/rclgd-sensors/ros_lidar/LidarStitch.glsl")
	var stitch_spirv: RDShaderSPIRV = stitch_file.get_spirv()
	_stitch_shader = _rd.shader_create_from_spirv(stitch_spirv)
	if _stitch_shader.is_valid():
		_stitch_pipeline = _rd.compute_pipeline_create(_stitch_shader)
		
	# 2. Face Capture Shader
	var capture_file: RDShaderFile = load("res://addons/rclgd-sensors/ros_lidar/LidarFaceCapture.glsl")
	var capture_spirv: RDShaderSPIRV = capture_file.get_spirv()
	_face_capture_shader = _rd.shader_create_from_spirv(capture_spirv)
	if _face_capture_shader.is_valid():
		_face_capture_pipeline = _rd.compute_pipeline_create(_face_capture_shader)

func _init_render_resources() -> void:
	# 1. Create a persistent parameters buffer (allocate 1200 bytes, which matches the float array size)
	var dummy_params = PackedFloat32Array()
	dummy_params.resize(300) # 300 floats = 1200 bytes
	var dummy_bytes = dummy_params.to_byte_array()
	_params_buffer = _rd.storage_buffer_create(dummy_bytes.size(), dummy_bytes)
	
	# 2. Create the persistent uniform set for the stitching shader
	var uniforms: Array[RDUniform] = []
	for i in range(6):
		var u = RDUniform.new()
		u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		u.binding = i
		u.add_id(_face_textures[i])
		uniforms.append(u)
		
	var params_uniform = RDUniform.new()
	params_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	params_uniform.binding = 6
	params_uniform.add_id(_params_buffer)
	uniforms.append(params_uniform)
	
	var points_uniform = RDUniform.new()
	points_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	points_uniform.binding = 7
	points_uniform.add_id(_points_buffer)
	uniforms.append(points_uniform)
	
	_stitch_uniform_set = _rd.uniform_set_create(uniforms, _stitch_shader, 0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _rd:
		# Free the uniform set first: freeing any of its dependencies (textures, buffer, shader)
		# makes Godot free it automatically, so it may already be gone.
		if _stitch_uniform_set.is_valid() and _rd.uniform_set_is_valid(_stitch_uniform_set):
			_rd.free_rid(_stitch_uniform_set)

		# Free texture RIDs
		for tex in _face_textures:
			if tex.is_valid():
				_rd.free_rid(tex)
		if _points_buffer.is_valid():
			_rd.free_rid(_points_buffer)
		
		# Free shaders
		if _stitch_shader.is_valid():
			_rd.free_rid(_stitch_shader)
		if _face_capture_shader.is_valid():
			_rd.free_rid(_face_capture_shader)
			
		# Free persistent RIDs (pipelines are freed along with their shaders)
		if _params_buffer.is_valid():
			_rd.free_rid(_params_buffer)

func _intervals_overlap(min1: float, max1: float, min2: float, max2: float) -> bool:
	return max1 >= min2 and min1 <= max2

func _back_overlaps(min1: float, max1: float) -> bool:
	return _intervals_overlap(min1, max1, 135.0, 180.0) or _intervals_overlap(min1, max1, -180.0, -135.0)

func _sample() -> void:
	if not is_visible_in_tree() or _queued_stamp != null or not _stitch_uniform_set.is_valid(): return

	_queued_stamp = _node.now()

	# Determine which viewports need to be rendered based on FOV configuration
	var render_mask = [false, false, false, false, false, false]
	
	# 0. Right (+X): [-135, -45]
	if vertical_fov_max >= -45.0 and vertical_fov_min <= 45.0:
		if _intervals_overlap(horizontal_fov_min, horizontal_fov_max, -135.0, -45.0):
			render_mask[0] = true
			
	# 1. Left (-X): [45, 135]
	if vertical_fov_max >= -45.0 and vertical_fov_min <= 45.0:
		if _intervals_overlap(horizontal_fov_min, horizontal_fov_max, 45.0, 135.0):
			render_mask[1] = true
			
	# 2. Up (+Y): [45, 90] vertically
	if vertical_fov_max >= 45.0:
		render_mask[2] = true
		
	# 3. Down (-Y): [-90, -45] vertically
	if vertical_fov_min <= -45.0:
		render_mask[3] = true
		
	# 4. Back (+Z): [135, 180] or [-180, -135]
	if vertical_fov_max >= -45.0 and vertical_fov_min <= 45.0:
		if _back_overlaps(horizontal_fov_min, horizontal_fov_max):
			render_mask[4] = true
			
	# 5. Forward (-Z): [-45, 45]
	if vertical_fov_max >= -45.0 and vertical_fov_min <= 45.0:
		if _intervals_overlap(horizontal_fov_min, horizontal_fov_max, -45.0, 45.0):
			render_mask[5] = true

	# Trigger Render on active viewports
	for i in range(6):
		if render_mask[i]:
			_viewports[i].render_target_update_mode = SubViewport.UPDATE_ONCE
	
	# WAIT for the frame to be drawn before requesting data
	if not RenderingServer.frame_post_draw.is_connected(_on_frame_drawn):
		RenderingServer.frame_post_draw.connect(_on_frame_drawn, CONNECT_ONE_SHOT)

# Readbacks take a few frames to arrive. A new scan doesn't wait for them: each readback carries
# its scan's stamp into the publish queue, which publishes in scan order.
func _on_frame_drawn():
	var stamp_ns := to_ns(_queued_stamp) # Callbacks bind only plain values (see RosSensor.to_ns)
	_queued_stamp = null

	# Serialize parameters on the main thread
	var params_bytes = _get_params_byte_array()
	
	# Dispatch stitching shader on the render thread
	RenderingServer.call_on_render_thread(_dispatch_stitching.bind(params_bytes, stamp_ns))

func _dispatch_stitching(params_bytes: PackedByteArray, stamp_ns: int) -> void:
	if not _stitch_shader.is_valid() or not _stitch_pipeline.is_valid() or not _points_buffer.is_valid() or not _stitch_uniform_set.is_valid():
		return
		
	# Update the persistent parameter buffer with the new matrix/range/noise data.
	# Buffer updates, dispatches and readbacks run in submission order, so overlapping scans are
	# safe: each readback copies the points buffer before the next scan overwrites it.
	_rd.buffer_update(_params_buffer, 0, params_bytes.size(), params_bytes)
	
	# Calculate groups (assuming local_size_x/y = 8 in the shader)
	var x_groups = (horizontal_resolution - 1) / 8 + 1
	var y_groups = (vertical_resolution - 1) / 8 + 1
	
	# Dispatch compute list
	var compute_list = _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(compute_list, _stitch_pipeline)
	_rd.compute_list_bind_uniform_set(compute_list, _stitch_uniform_set, 0)
	_rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	_rd.compute_list_end()
	
	# Request data asynchronously (sequenced after the compute commands)
	_rd.buffer_get_data_async(_points_buffer, _on_points_ready.bind(stamp_ns))

func _on_points_ready(raw_bytes: PackedByteArray, stamp_ns: int) -> void:
	if not raw_bytes.is_empty():
		_publish_queue.push([stamp_ns, raw_bytes])

# Runs on the queue's thread, one scan at a time, so it can reuse _cached_msg
func _publish(stamp_ns: int, raw_bytes: PackedByteArray) -> void:
	write_stamp(_cached_msg.header, stamp_ns)
	_cached_msg.data = raw_bytes
	_lidar_pub.publish(_cached_msg)

func _get_params_byte_array() -> PackedByteArray:
	_params_float_array[0] = float(horizontal_resolution)
	_params_float_array[1] = float(vertical_resolution)
	_params_float_array[2] = randf()
	_params_float_array[3] = noise_std_dev
	_params_float_array[4] = deg_to_rad(vertical_fov_min)
	_params_float_array[5] = deg_to_rad(vertical_fov_max)
	_params_float_array[6] = deg_to_rad(horizontal_fov_min)
	_params_float_array[7] = deg_to_rad(horizontal_fov_max)
	_params_float_array[8] = min_range
	_params_float_array[9] = max_range
	_params_float_array[10] = 0.0
	_params_float_array[11] = 0.0
	
	for i in range(6):
		var inv_proj = _effects[i].inv_proj_matrix
		_write_projection_to_array(inv_proj, 12 + i * 16)
		
	for i in range(6):
		var trans = _remote_syncs[i].transform
		_write_transform_to_array(trans, 108 + i * 16)
		
	for i in range(6):
		var trans = _remote_syncs[i].transform
		var inv_trans = trans.affine_inverse()
		_write_transform_to_array(inv_trans, 204 + i * 16)
		
	return _params_float_array.to_byte_array()

func _write_projection_to_array(proj: Projection, index: int) -> void:
	_params_float_array[index]      = proj.x.x
	_params_float_array[index + 1]  = proj.x.y
	_params_float_array[index + 2]  = proj.x.z
	_params_float_array[index + 3]  = proj.x.w
	_params_float_array[index + 4]  = proj.y.x
	_params_float_array[index + 5]  = proj.y.y
	_params_float_array[index + 6]  = proj.y.z
	_params_float_array[index + 7]  = proj.y.w
	_params_float_array[index + 8]  = proj.z.x
	_params_float_array[index + 9]  = proj.z.y
	_params_float_array[index + 10] = proj.z.z
	_params_float_array[index + 11] = proj.z.w
	_params_float_array[index + 12] = proj.w.x
	_params_float_array[index + 13] = proj.w.y
	_params_float_array[index + 14] = proj.w.z
	_params_float_array[index + 15] = proj.w.w

func _write_transform_to_array(t: Transform3D, index: int) -> void:
	_params_float_array[index]      = t.basis.x.x
	_params_float_array[index + 1]  = t.basis.x.y
	_params_float_array[index + 2]  = t.basis.x.z
	_params_float_array[index + 3]  = 0.0
	_params_float_array[index + 4]  = t.basis.y.x
	_params_float_array[index + 5]  = t.basis.y.y
	_params_float_array[index + 6]  = t.basis.y.z
	_params_float_array[index + 7]  = 0.0
	_params_float_array[index + 8]  = t.basis.z.x
	_params_float_array[index + 9]  = t.basis.z.y
	_params_float_array[index + 10] = t.basis.z.z
	_params_float_array[index + 11] = 0.0
	_params_float_array[index + 12] = t.origin.x
	_params_float_array[index + 13] = t.origin.y
	_params_float_array[index + 14] = t.origin.z
	_params_float_array[index + 15] = 1.0

func _prepare_msg_template() -> void:
	_cached_msg = RosSensorMsgsPointCloud2.new()
	_cached_msg.header.frame_id = _frame
	# Organized cloud: rows are beams, so consumers can walk neighbors along and across rings
	_cached_msg.height = vertical_resolution
	_cached_msg.width = horizontal_resolution
	_cached_msg.point_step = POINT_STEP
	_cached_msg.row_step = horizontal_resolution * POINT_STEP
	_cached_msg.is_dense = false # Beams without a return are NaN
	const FLOAT32 = 7
	const UINT16 = 4
	_cached_msg.fields = [
		_create_field("x", 0, FLOAT32), _create_field("y", 4, FLOAT32),
		_create_field("z", 8, FLOAT32), _create_field("intensity", 12, FLOAT32),
		_create_field("ring", 16, UINT16),
	]

func _create_field(fname: String, offset: int, datatype: int) -> RosSensorMsgsPointField:
	var f = RosSensorMsgsPointField.new()
	f.name = fname; f.offset = offset; f.datatype = datatype; f.count = 1
	return f
