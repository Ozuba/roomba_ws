extends CompositorEffect
class_name LidarFaceCompositorEffect

# --- Configuration (Set by the Lidar node externally) ---
var texture_size: Vector2 = Vector2(256, 256) 
# --- RIDs ---
var target_tex: RID # The texture we output to 
var rd: RenderingDevice
var nearest_sampler: RID
var shader: RID = RID()
var pipeline: RID = RID()
var inv_proj_matrix: Projection = Projection.IDENTITY

var _cached_depth_tex: RID = RID()
var _cached_color_tex: RID = RID()
var _cached_uniform_set: RID = RID()

# --- Initialization ---

func _init() -> void:
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	RenderingServer.call_on_render_thread(_initialize_sampler)

func _notification(what: int) -> void:
	# Cleanup: Fires when the resource is freed. It must clean up nearest_sampler.
	if what == NOTIFICATION_PREDELETE and rd:
		if nearest_sampler.is_valid():
			rd.free_rid(nearest_sampler)
		# The uniform set is auto-freed by Godot when its textures/shader are freed (e.g. by RosLidar)
		if _cached_uniform_set.is_valid() and rd.uniform_set_is_valid(_cached_uniform_set):
			rd.free_rid(_cached_uniform_set)

func _initialize_sampler() -> void:
	rd = RenderingServer.get_rendering_device()
	if !rd:
		return
		
	# Create Sampler
	var sampler_state: RDSamplerState = RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	nearest_sampler = rd.sampler_create(sampler_state)


# --- Render Callback (The Execution Loop) ---
func _render_callback(p_effect_callback_type: int, p_render_data: RenderData) -> void:
	# 1. CRITICAL VALIDITY CHECK: Avoid race conditions from asynchronous init
	if not shader.is_valid() or not pipeline.is_valid() or not target_tex.is_valid():
		return
		
	if rd and p_effect_callback_type == CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:
		
		var render_scene_buffers: RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()
		var render_scene_data: RenderSceneData = p_render_data.get_render_scene_data()
		
		if not render_scene_buffers or not render_scene_data:
			return

		# Capture the Vulkan-adjusted inverse projection matrix
		inv_proj_matrix = render_scene_data.get_cam_projection().inverse()
		var push_constant := _projection_bytes(inv_proj_matrix)

		var size: Vector2i = render_scene_buffers.get_internal_size()
		if size.x == 0 or size.y == 0:
			return

		# Compute Dispatch Groups (assuming local_size_x/y = 8 in the shader)
		var x_groups: int = (size.x - 1) / 8 + 1
		var y_groups: int = (size.y - 1) / 8 + 1
		
		for view in range(render_scene_buffers.get_view_count()):
			var depth_tex: RID = render_scene_buffers.get_depth_layer(view)
			var color_tex: RID = render_scene_buffers.get_color_layer(view)

			var set_alive: bool = _cached_uniform_set.is_valid() and rd.uniform_set_is_valid(_cached_uniform_set)
			if depth_tex != _cached_depth_tex or color_tex != _cached_color_tex or not set_alive:
				if set_alive:
					rd.free_rid(_cached_uniform_set)
				
				_cached_depth_tex = depth_tex
				_cached_color_tex = color_tex
				
				# U0: Depth Sampler
				var depth_uniform: RDUniform = RDUniform.new()
				depth_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
				depth_uniform.binding = 0
				depth_uniform.add_id(nearest_sampler)
				depth_uniform.add_id(depth_tex)
				
				# U1: Color Sampler
				var color_uniform: RDUniform = RDUniform.new()
				color_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
				color_uniform.binding = 1
				color_uniform.add_id(nearest_sampler)
				color_uniform.add_id(color_tex)
				
				# U2: Output Image/Buffer
				var target_copy_uniform: RDUniform = RDUniform.new()
				target_copy_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
				target_copy_uniform.binding = 2
				target_copy_uniform.add_id(target_tex)
				
				_cached_uniform_set = rd.uniform_set_create([depth_uniform, color_uniform, target_copy_uniform], shader, 0)

			var compute_list := rd.compute_list_begin()
			rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
			rd.compute_list_bind_uniform_set(compute_list, _cached_uniform_set, 0)
			rd.compute_list_set_push_constant(compute_list, push_constant, push_constant.size())
			rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
			rd.compute_list_end()

static func _projection_bytes(proj: Projection) -> PackedByteArray:
	return PackedFloat32Array([
		proj.x.x, proj.x.y, proj.x.z, proj.x.w,
		proj.y.x, proj.y.y, proj.y.z, proj.y.w,
		proj.z.x, proj.z.y, proj.z.z, proj.z.w,
		proj.w.x, proj.w.y, proj.w.z, proj.w.w,
	]).to_byte_array()
