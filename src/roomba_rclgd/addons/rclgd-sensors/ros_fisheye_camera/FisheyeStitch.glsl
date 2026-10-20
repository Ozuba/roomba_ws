#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D face_forward;
layout(set = 0, binding = 1) uniform sampler2D face_left;
layout(set = 0, binding = 2) uniform sampler2D face_right;
layout(set = 0, binding = 3) uniform sampler2D face_up;
layout(set = 0, binding = 4) uniform sampler2D face_down;
layout(set = 0, binding = 5) uniform sampler2D face_back;
layout(set = 0, binding = 6, rgba8) uniform writeonly image2D output_image;

layout(set = 0, binding = 7, std140) uniform Params {
    int projection_type; // 0 = Circular Fisheye, 1 = Equirectangular
    float max_theta;     // Maximum angle of the fisheye lens in radians
    float aspect_ratio;
    float use_custom_calibration;
    
    vec4 intrinsics; // x = fx, y = fy, z = cx, w = cy
    vec4 distortion; // x = k1, y = k2, z = k3, w = k4
} params;

#define PI 3.14159265359

void main() {
    ivec2 xy = ivec2(gl_GlobalInvocationID.xy);
    ivec2 dest_size = imageSize(output_image);
    
    if (xy.x >= dest_size.x || xy.y >= dest_size.y) {
        return;
    }
    
    float theta = 0.0;
    float phi = 0.0;
    
    if (params.use_custom_calibration > 0.5) {
        // Real-camera calibration path (Kannala-Brandt model mapping)
        vec2 p_offset = vec2(xy) - params.intrinsics.zw;
        float theta_d = length(p_offset / params.intrinsics.xy);
        
        if (theta_d < 0.00001) {
            theta = 0.0;
            phi = 0.0;
        } else {
            theta = theta_d; // Initial guess
            for (int i = 0; i < 4; i++) {
                float t2 = theta * theta;
                float t4 = t2 * t2;
                float t6 = t4 * t2;
                float t8 = t4 * t4;
                float f = theta * (1.0 + params.distortion.x * t2 + params.distortion.y * t4 + params.distortion.z * t6 + params.distortion.w * t8) - theta_d;
                float df = 1.0 + 3.0 * params.distortion.x * t2 + 5.0 * params.distortion.y * t4 + 7.0 * params.distortion.z * t6 + 9.0 * params.distortion.w * t8;
                theta -= f / df;
            }
            // Image rows grow downward, local +Y is up
            phi = atan(-p_offset.y / params.intrinsics.y, p_offset.x / params.intrinsics.x);
        }
        
        // If the calculated theta exceeds the lens limit (FOV), paint it black
        if (theta > params.max_theta) {
            imageStore(output_image, xy, vec4(0.0, 0.0, 0.0, 1.0));
            return;
        }
    } 
    else {
        // Ideal simulation path
        if (params.projection_type == 0) {
            // Circular Fisheye
            vec2 uv = (vec2(xy) + vec2(0.5)) / vec2(dest_size);
            vec2 d_uv = uv - vec2(0.5);
            
            vec2 scaled_uv = d_uv * 2.0;
            scaled_uv.x *= params.aspect_ratio;
            
            float r = length(scaled_uv);
            
            if (r > 1.0) {
                imageStore(output_image, xy, vec4(0.0, 0.0, 0.0, 1.0));
                return;
            }
            
            theta = r * params.max_theta;
            // Image rows grow downward, local +Y is up
            phi = atan(-scaled_uv.y, scaled_uv.x);
        } 
        else {
            // Equirectangular (Panorama 360)
            vec2 uv = vec2(xy) / vec2(dest_size);
            float lambda = (uv.x - 0.5) * 2.0 * PI; // Longitude: [-PI, PI]
            float varphi = (0.5 - uv.y) * PI;       // Latitude: [-PI/2, PI/2]
            
            // Convert to spherical direction
            vec3 D;
            D.x = cos(varphi) * sin(lambda);
            D.y = sin(varphi);
            D.z = -cos(varphi) * cos(lambda);
            
            // Convert D back to theta/phi relative to camera -Z axis for face sampling
            theta = acos(clamp(-D.z, -1.0, 1.0));
            phi = atan(D.y, D.x);
        }
    }
    
    // Calculate final 3D ray direction in local space
    vec3 D;
    D.x = sin(theta) * cos(phi);
    D.y = sin(theta) * sin(phi);
    D.z = -cos(theta);
    
    vec4 color = vec4(0.0, 0.0, 0.0, 1.0);
    
    float abs_x = abs(D.x);
    float abs_y = abs(D.y);
    float abs_z = abs(D.z);
    
    // Sample from the correct face of the 6-sided cubemap
    if (D.z < 0.0 && -D.z >= abs_x && -D.z >= abs_y) {
        // Forward face (-Z)
        vec2 uv_samp = vec2(
            0.5 + 0.5 * (D.x / -D.z),
            0.5 - 0.5 * (D.y / -D.z)
        );
        color = texture(face_forward, uv_samp);
    } 
    else if (D.x > 0.0 && D.x >= abs_y && D.x >= abs_z) {
        // Right face (+X)
        vec2 uv_samp = vec2(
            0.5 + 0.5 * (D.z / D.x),
            0.5 - 0.5 * (D.y / D.x)
        );
        color = texture(face_right, uv_samp);
    } 
    else if (D.x < 0.0 && -D.x >= abs_y && -D.x >= abs_z) {
        // Left face (-X)
        vec2 uv_samp = vec2(
            0.5 - 0.5 * (D.z / -D.x),
            0.5 - 0.5 * (D.y / -D.x)
        );
        color = texture(face_left, uv_samp);
    } 
    else if (D.y > 0.0 && D.y >= abs_x && D.y >= abs_z) {
        // Up face (+Y)
        vec2 uv_samp = vec2(
            0.5 + 0.5 * (D.x / D.y),
            0.5 + 0.5 * (D.z / D.y)
        );
        color = texture(face_up, uv_samp);
    } 
    else if (D.y < 0.0 && -D.y >= abs_x && -D.y >= abs_z) {
        // Down face (-Y)
        vec2 uv_samp = vec2(
            0.5 + 0.5 * (D.x / -D.y),
            0.5 - 0.5 * (D.z / -D.y)
        );
        color = texture(face_down, uv_samp);
    }
    else if (D.z > 0.0 && D.z >= abs_x && D.z >= abs_y) {
        // Back face (+Z)
        vec2 uv_samp = vec2(
            0.5 - 0.5 * (D.x / D.z),
            0.5 - 0.5 * (D.y / D.z)
        );
        color = texture(face_back, uv_samp);
    }
    
    imageStore(output_image, xy, color);
}
