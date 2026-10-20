#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set=0, binding=0) uniform sampler2D depth_buffer;
layout(set=0, binding=1) uniform sampler2D color_buffer;
layout(set=0, binding=2, rgba32f) uniform restrict writeonly image2D face_out;

layout(push_constant, std430) uniform Params {
    mat4 inv_proj_matrix; // Inverse projection of the face camera, for this render
} params;

// View-space position of a depth-buffer sample (reversed-Z). ndc comes from pixel rows (y down);
// the projection expects y up, as in DepthCapture.glsl and LidarStitch.glsl
vec3 get_view_pos(vec2 ndc, float depth) {
    vec4 view_pos = params.inv_proj_matrix * vec4(ndc.x, -ndc.y, depth, 1.0);
    return view_pos.xyz / view_pos.w;
}

void main() {
    ivec2 xy = ivec2(gl_GlobalInvocationID.xy);
    ivec2 dest_size = imageSize(face_out);
    
    if (xy.x >= dest_size.x || xy.y >= dest_size.y) {
        return;
    }

    // Sample depth and color using integer coordinates (texelFetch)
    float depth = texelFetch(depth_buffer, xy, 0).r;
    vec4 color = texelFetch(color_buffer, xy, 0);
    float base_intensity = (color.r + color.g + color.b) / 3.0;

    // A depth close to 0.0 (or very close) means nothing was hit (sky/far plane)
    if (depth <= 0.0001) {
        imageStore(face_out, xy, vec4(depth, base_intensity, 0.0, 0.0));
        return;
    }

    vec2 inv_dest_size = 1.0 / vec2(dest_size);

    // Calculate view-space ray direction (Camera looks down -Z)
    vec2 ndc = (vec2(xy) + 0.5) * inv_dest_size * 2.0 - 1.0;
    vec3 p = get_view_pos(ndc, depth);
    vec3 ray_dir = normalize(p);

    // Reconstruct view-space normal from depth buffer neighbors
    ivec2 xy_right = clamp(xy + ivec2(1, 0), ivec2(0), dest_size - 1);
    float depth_right = texelFetch(depth_buffer, xy_right, 0).r;
    vec2 ndc_right = (vec2(xy_right) + 0.5) * inv_dest_size * 2.0 - 1.0;
    vec3 p_right = get_view_pos(ndc_right, depth_right);

    ivec2 xy_down = clamp(xy + ivec2(0, 1), ivec2(0), dest_size - 1);
    float depth_down = texelFetch(depth_buffer, xy_down, 0).r;
    vec2 ndc_down = (vec2(xy_down) + 0.5) * inv_dest_size * 2.0 - 1.0;
    vec3 p_down = get_view_pos(ndc_down, depth_down);

    vec3 t1 = p_right - p;
    vec3 t2 = p_down - p;
    vec3 normal = normalize(cross(t1, t2));

    // Compute angle of incidence (Lambertian cosine law). abs(): the normal's sign depends on
    // the winding of the two neighbor offsets
    float cos_theta = clamp(abs(dot(normal, ray_dir)), 0.0, 1.0);

    // Reflected intensity
    float intensity = base_intensity * cos_theta;

    // Store in output face texture: R = depth, G = intensity
    imageStore(face_out, xy, vec4(depth, intensity, 0.0, 0.0));
}
