shader_type spatial;
// Procedural wooden floor planks, laid out in world space so any floor mesh size works.

uniform vec3 color_light : source_color = vec3(0.66, 0.48, 0.31);
uniform vec3 color_dark : source_color = vec3(0.47, 0.32, 0.20);
uniform float plank_width = 0.16;
uniform float plank_length = 1.3;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float row = floor(p.x / plank_width);
	float offset = hash(vec2(row, 7.0)) * plank_length;
	float col = floor((p.y + offset) / plank_length);
	float id = hash(vec2(row, col));
	vec2 f = vec2(fract(p.x / plank_width), fract((p.y + offset) / plank_length));

	float grain = sin(p.y * 38.0 + id * 25.0 + sin(p.x * 55.0 + id * 9.0) * 1.3) * 0.5 + 0.5;
	vec3 c = mix(color_light, color_dark, id * 0.65 + grain * 0.2);
	float seam = max(1.0 - smoothstep(0.0, 0.035, f.x), 1.0 - smoothstep(0.0, 0.006, f.y));
	ALBEDO = c * (1.0 - seam * 0.45);
	ROUGHNESS = 0.45 + grain * 0.15;
	SPECULAR = 0.4;
}
