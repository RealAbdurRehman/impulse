shader_type spatial;

#include "res://scripts/world/shaders/stage_light.gdshaderinc"

uniform vec4 tint : source_color = vec4(0.32, 0.32, 0.345, 1.0);
uniform vec4 glow : source_color = vec4(0.9, 0.92, 1.0, 1.0);
uniform vec2 panel = vec2(4.0, 3.0);
uniform float wash : hint_range(0.0, 4.0) = 1.6;

varying vec3 world;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = world.xy / panel;
	vec2 across = fract(cell) - 0.5;
	vec2 edge = (0.5 - abs(across)) * panel;
	float groove = 1.0 - smoothstep(0.0, 0.03, min(edge.x, edge.y));
	vec2 bevel = 1.0 - smoothstep(vec2(0.0), vec2(0.09), edge);

	float tone = 1.0 + (hash(floor(cell)) - 0.5) * 0.08;
	float fine = noise(world.xy * 16.0) * 0.5 + noise(world.xy * 3.0) * 0.5;
	float low = mix(0.7, 1.0, smoothstep(0.0, 3.2, world.y));

	ALBEDO = tint.rgb * tone * (0.95 + fine * 0.07) * low * (1.0 - groove * 0.22);
	ROUGHNESS = mix(0.9, 0.65, max(bevel.x, bevel.y));
	SPECULAR = 0.3;

	vec3 right = (VIEW_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz;
	vec3 lift = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	NORMAL = normalize(NORMAL + right * sign(across.x) * bevel.x * 0.35 + lift * sign(across.y) * bevel.y * 0.35);

	EMISSION = glow.rgb * tint.rgb * wall_pool(world.xy) * wash;
}
