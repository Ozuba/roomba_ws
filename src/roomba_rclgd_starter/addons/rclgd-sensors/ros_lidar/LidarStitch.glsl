#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// 6 input face textures (R = depth, G = intensity)
layout(set=0, binding=0, rgba32f) uniform restrict readonly image2D face0;
layout(set=0, binding=1, rgba32f) uniform restrict readonly image2D face1;
layout(set=0, binding=2, rgba32f) uniform restrict readonly image2D face2;
layout(set=0, binding=3, rgba32f) uniform restrict readonly image2D face3;
layout(set=0, binding=4, rgba32f) uniform restrict readonly image2D face4;
layout(set=0, binding=5, rgba32f) uniform restrict readonly image2D face5;

layout(set=0, binding=6, std430) restrict buffer Params {
    vec2 resolution;       // Output resolution (H_RES, V_RES)
    float seed;            // Time-based seed to animate noise
    float noise_std_dev;   // Standard deviation for Gaussian noise
    float vertical_fov_min;// Rad
    float vertical_fov_max;// Rad
    float horizontal_fov_min; // Rad
    float horizontal_fov_max; // Rad
    float min_range;       // Meters
    float max_range;       // Meters
    float pad1;            // Explicit padding to align to 16-byte boundary
    float pad2;            // Explicit padding to align to 16-byte boundary
    mat4 inv_proj_matrices[6];
    mat4 cam_transforms[6];
    mat4 inv_cam_transforms[6];
} params;

// Output: PointCloud2 data, row-major (one row per beam). Each 20-byte point is
// x, y, z, intensity (float32, ROS axes) + ring (uint16) + 2 bytes padding.
layout(set=0, binding=7, std430) restrict writeonly buffer Points {
    uint words[];
} points;

const float PI = 3.14159265359;
const uint POINT_WORDS = 5u;

// quiet NaN: the PointCloud2 "no point" (a function: GLSL consts can't use uintBitsToFloat)
float no_return() {
    return uintBitsToFloat(0x7fc00000u);
}

void store_point(ivec2 xy, vec3 ros_point, float intensity) {
    uint base = (uint(xy.y) * uint(params.resolution.x) + uint(xy.x)) * POINT_WORDS;
    points.words[base + 0u] = floatBitsToUint(ros_point.x);
    points.words[base + 1u] = floatBitsToUint(ros_point.y);
    points.words[base + 2u] = floatBitsToUint(ros_point.z);
    points.words[base + 3u] = floatBitsToUint(intensity);
    points.words[base + 4u] = uint(xy.y); // ring (little-endian uint16 + zero padding)
}

// Generate uniform random numbers
float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233) + params.seed)) * 43758.5453);
}

// Box-Muller Transform for Gaussian noise
float get_gaussian(vec2 co, float std_dev) {
    float u1 = max(rand(co), 1e-6); 
    float u2 = rand(co + 1.0);
    return sqrt(-2.0 * log(u1)) * cos(2.0 * PI * u2) * std_dev;
}

void main() {
    ivec2 xy = ivec2(gl_GlobalInvocationID.xy);
    ivec2 dest_size = ivec2(params.resolution);

    if (xy.x >= dest_size.x || xy.y >= dest_size.y) {
        return;
    }

    // 1. Calculate the spherical ray direction in Lidar local space
    // Normalize coordinates
    float u = (float(xy.x) + 0.5) / params.resolution.x;
    float w = (float(xy.y) + 0.5) / params.resolution.y;

    float theta = params.horizontal_fov_min + u * (params.horizontal_fov_max - params.horizontal_fov_min);
    float phi = params.vertical_fov_min + w * (params.vertical_fov_max - params.vertical_fov_min); // Pitch

    vec3 d_local;
    d_local.x = sin(theta) * cos(phi);
    d_local.y = sin(phi);
    d_local.z = -cos(theta) * cos(phi); // Forward is -Z in Godot

    // 2. Find which camera face this direction vector projects onto
    // Direct selection by maximum absolute component (maps to cubemap faces)
    int best_cam = -1;
    float abs_x = abs(d_local.x);
    float abs_y = abs(d_local.y);
    float abs_z = abs(d_local.z);

    if (abs_x >= abs_y && abs_x >= abs_z) {
        if (d_local.x > 0.0) {
            best_cam = 0; // +X (Right)
        } else {
            best_cam = 1; // -X (Left)
        }
    } else if (abs_y >= abs_x && abs_y >= abs_z) {
        if (d_local.y > 0.0) {
            best_cam = 2; // +Y (Up)
        } else {
            best_cam = 3; // -Y (Down)
        }
    } else {
        if (d_local.z > 0.0) {
            best_cam = 4; // +Z (Back)
        } else {
            best_cam = 5; // -Z (Forward)
        }
    }

    // Project direction vector onto the selected camera face's local coordinate frame
    vec3 d_cam = (params.inv_cam_transforms[best_cam] * vec4(d_local, 0.0)).xyz;
    float front_z = -d_cam.z;
    
    // Ensure the projection is pointing in the camera's visual frustum
    if (front_z <= 1e-4) {
        store_point(xy, vec3(no_return()), 0.0);
        return;
    }

    float best_x_ndc = d_cam.x / front_z;
    float best_y_ndc = d_cam.y / front_z;

    // 3. Load depth and intensity from the selected face texture
    // Texture coordinates have V=0 at the top (which corresponds to positive y_ndc)
    vec2 lookup_uv;
    lookup_uv.x = best_x_ndc * 0.5 + 0.5;
    lookup_uv.y = 0.5 - best_y_ndc * 0.5; // Vulkan Y-flip

    ivec2 face_size = imageSize(face0); // Assuming all faces are same size
    ivec2 face_xy = ivec2(lookup_uv * vec2(face_size));
    face_xy = clamp(face_xy, ivec2(0), face_size - 1);

    vec4 val = vec4(0.0);
    switch (best_cam) {
        case 0: val = imageLoad(face0, face_xy); break;
        case 1: val = imageLoad(face1, face_xy); break;
        case 2: val = imageLoad(face2, face_xy); break;
        case 3: val = imageLoad(face3, face_xy); break;
        case 4: val = imageLoad(face4, face_xy); break;
        case 5: val = imageLoad(face5, face_xy); break;
    }

    float depth_raw = val.r;
    float intensity = val.g;

    // In Godot 4, Vulkan uses reversed-Z depth buffer (1.0 = near plane, 0.0 = far plane).
    // A depth of 0.0 (or very close) means nothing was hit (sky/far plane).
    if (depth_raw <= 0.0001) {
        store_point(xy, vec3(no_return()), 0.0);
        return;
    }

    // 4. Reconstruct the view-space position in the face camera's space
    vec4 ndc = vec4(best_x_ndc, best_y_ndc, depth_raw, 1.0);
    vec4 view_pos = params.inv_proj_matrices[best_cam] * ndc;
    view_pos /= view_pos.w;

    // 5. Transform back to Lidar local space
    vec4 local_point = params.cam_transforms[best_cam] * vec4(view_pos.xyz, 1.0);

    // Calculate actual distance/range
    float dist = length(local_point.xyz);

    // Apply range limits
    if (dist < params.min_range || dist > params.max_range) {
        store_point(xy, vec3(no_return()), 0.0);
        return;
    }

    // 6. Add Gaussian noise along the ray
    float noisy_dist = dist;
    if (params.noise_std_dev > 0.00001) {
        // Scale standard deviation based on:
        // - Distance: noise scales quadratically with distance (signal attenuation)
        // - Intensity: lower reflectivity or grazing angles (slanted surfaces) increase range uncertainty
        float intensity_factor = 1.0 / max(intensity, 0.05);
        float distance_factor = 1.0 + 0.001 * (dist * dist);
        float effective_std_dev = params.noise_std_dev * intensity_factor * distance_factor;

        float noise = get_gaussian(vec2(xy), effective_std_dev);
        noisy_dist = max(dist + noise, params.min_range);
    }
    vec3 local_noisy_point = d_local * noisy_dist;

    // 7. Convert to ROS frame:
    // Godot local -> ROS frame
    // ROS X = Forward = Godot Z
    // ROS Y = Left = Godot X
    // ROS Z = Up = Godot Y
    vec3 ros_point;
    ros_point.x = -local_noisy_point.z;
    ros_point.y = -local_noisy_point.x;
    ros_point.z = local_noisy_point.y;

    store_point(xy, ros_point, intensity);
}
