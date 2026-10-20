extends CompositorEffect
class_name DepthCaptureCompositorEffect

# --- Configuration (Set by the RosCamera node externally) ---
var target_tex: RID # The linear-depth output texture we write to (R32F)
var rd: RenderingDevice
var nearest_sampler: RID
var shader: RID = RID()
var pipeline: RID = RID()

# --- RIDs ---
var _params_buffer: RID = RID()
var _cached_depth_tex: RID = RID()
var _cached_uniform_set: RID = RID()
var _params_bytes: PackedByteArray = PackedByteArray()

# --- Initialization ---

func _init() -> void:
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	_params_bytes.resize(64) # mat4 = 16 floats = 64 bytes
	RenderingServer.call_on_render_thread(_initialize_render_resources)

func _notification(what: int) -> void:
	# Cleanup: Fires when the resource is freed. It must clean up its own RIDs.
	if what == NOTIFICATION_PREDELETE and rd:
		if nearest_sampler.is_valid():
			rd.free_rid(nearest_sampler)
		if _params_buffer.is_valid():
			rd.free_rid(_params_buffer)
		# The uniform set is auto-freed by Godot when its textures/shader are freed (e.g. by RosCamera)
		if _cached_uniform_set.is_valid() and rd.uniform_set_is_valid(_cached_uniform_set):
			rd.free_rid(_cached_uniform_set)

func _initialize_render_resources() -> void:
	rd = RenderingServer.get_rendering_device()
	if not rd:
		return

	var sampler_state: RDSamplerState = RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	nearest_sampler = rd.sampler_create(sampler_state)

	_params_buffer = rd.storage_buffer_create(_params_bytes.size())


# --- Render Callback (The Execution Loop) ---
func _render_callback(p_effect_callback_type: int, p_render_data: RenderData) -> void:
	if not shader.is_valid() or not pipeline.is_valid() or not target_tex.is_valid() or not _params_buffer.is_valid():
		return

	if rd and p_effect_callback_type == CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:

		var render_scene_buffers: RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()
		var render_scene_data: RenderSceneData = p_render_data.get_render_scene_data()

		if not render_scene_buffers or not render_scene_data:
			return

		var inv_proj_matrix: Projection = render_scene_data.get_cam_projection().inverse()
		_write_projection_to_buffer(inv_proj_matrix)
		rd.buffer_update(_params_buffer, 0, _params_bytes.size(), _params_bytes)

		var size: Vector2i = render_scene_buffers.get_internal_size()
		if size.x == 0 or size.y == 0:
			return

		# Compute Dispatch Groups (assuming local_size_x/y = 8 in the shader)
		var x_groups: int = (size.x - 1) / 8 + 1
		var y_groups: int = (size.y - 1) / 8 + 1

		for view in range(render_scene_buffers.get_view_count()):
			var depth_tex: RID = render_scene_buffers.get_depth_layer(view)

			var set_alive: bool = _cached_uniform_set.is_valid() and rd.uniform_set_is_valid(_cached_uniform_set)
			if depth_tex != _cached_depth_tex or not set_alive:
				if set_alive:
					rd.free_rid(_cached_uniform_set)

				_cached_depth_tex = depth_tex

				# U0: Depth Sampler
				var depth_uniform: RDUniform = RDUniform.new()
				depth_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
				depth_uniform.binding = 0
				depth_uniform.add_id(nearest_sampler)
				depth_uniform.add_id(depth_tex)

				# U1: Inverse projection params
				var params_uniform: RDUniform = RDUniform.new()
				params_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
				params_uniform.binding = 1
				params_uniform.add_id(_params_buffer)

				# U2: Output Image
				var target_uniform: RDUniform = RDUniform.new()
				target_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
				target_uniform.binding = 2
				target_uniform.add_id(target_tex)

				_cached_uniform_set = rd.uniform_set_create([depth_uniform, params_uniform, target_uniform], shader, 0)

			var compute_list := rd.compute_list_begin()
			rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
			rd.compute_list_bind_uniform_set(compute_list, _cached_uniform_set, 0)
			rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
			rd.compute_list_end()

func _write_projection_to_buffer(proj: Projection) -> void:
	var f := PackedFloat32Array([
		proj.x.x, proj.x.y, proj.x.z, proj.x.w,
		proj.y.x, proj.y.y, proj.y.z, proj.y.w,
		proj.z.x, proj.z.y, proj.z.z, proj.z.w,
		proj.w.x, proj.w.y, proj.w.z, proj.w.w,
	])
	_params_bytes = f.to_byte_array()
