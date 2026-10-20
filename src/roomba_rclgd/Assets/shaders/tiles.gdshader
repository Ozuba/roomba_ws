shader_type spatial;
// Procedural square floor tiles with grout lines, laid out in world space.

uniform vec3 tile_color : source_color = vec3(0.86, 0.85, 0.82);
uniform vec3 grout_color : source_color = vec3(0.55, 0.53, 0.50);
uniform float tile_size = 0.4;
uniform float grout_width = 0.012;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = floor(world_pos.xz / tile_size);
	vec2 f = fract(world_pos.xz / tile_size) * tile_size;
	float edge = min(min(f.x, tile_size - f.x), min(f.y, tile_size - f.y));
	float grout = 1.0 - smoothstep(grout_width * 0.5, grout_width, edge);
	vec3 c = tile_color * (0.95 + hash(cell) * 0.08);
	ALBEDO = mix(c, grout_color, grout);
	ROUGHNESS = mix(0.18, 0.9, grout);
	SPECULAR = 0.6;
}
