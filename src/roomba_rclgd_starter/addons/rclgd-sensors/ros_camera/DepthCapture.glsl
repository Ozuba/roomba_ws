#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set=0, binding=0) uniform sampler2D depth_buffer;
layout(set=0, binding=1, std430) restrict readonly buffer Params {
    mat4 inv_proj_matrix;
} params;
layout(set=0, binding=2, r32f) uniform restrict writeonly image2D depth_out;

void main() {
    ivec2 xy = ivec2(gl_GlobalInvocationID.xy);
    ivec2 dest_size = imageSize(depth_out);

    if (xy.x >= dest_size.x || xy.y >= dest_size.y) {
        return;
    }

    float depth_raw = texelFetch(depth_buffer, xy, 0).r;

    // Reversed-Z: ~0 means nothing was hit (sky/far plane). ROS depth convention uses 0 for "no return".
    if (depth_raw <= 0.0001) {
        imageStore(depth_out, xy, vec4(0.0));
        return;
    }

    vec2 ndc = (vec2(xy) + 0.5) / vec2(dest_size) * 2.0 - 1.0;
    ndc.y = -ndc.y;

    // Standard NDC -> view-space reconstruction (w defaults to 1, then divided back out).
    vec4 view_pos = params.inv_proj_matrix * vec4(ndc, depth_raw, 1.0);
    view_pos /= view_pos.w;

    // Camera looks down -Z in view space; ROS depth images store distance along the optical axis.
    imageStore(depth_out, xy, vec4(-view_pos.z, 0.0, 0.0, 0.0));
}
