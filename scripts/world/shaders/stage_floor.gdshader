shader_type spatial;

global uniform float wetness;

#include "res://scripts/world/shaders/stage_light.gdshaderinc"

uniform sampler2D grain : source_color, repeat_enable, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.22, 0.22, 0.24, 1.0);
uniform vec4 glow : source_color = vec4(0.9, 0.92, 1.0, 1.0);
uniform float grain_scale = 0.18;
uniform float lines : hint_range(0.0, 1.0) = 0.5;
uniform float lit : hint_range(0.0, 8.0) = 1.1;
uniform float gloss : hint_range(0.0, 2.0) = 0.7;
uniform float mirror_base = 0.04;
uniform float mirror_gain = 0.3;

varying vec3 world;
varying vec3 up;

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float grid(vec2 p, float size, float width) {
	vec2 q = p / size;
	vec2 g = abs(fract(q - 0.5) - 0.5) / max(fwidth(q), vec2(0.0001));
	return 1.0 - clamp(min(g.x, g.y) / width, 0.0, 1.0);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	up = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec2 p = world.xz;
	float pool = floor_pool(p);
	float base = texture(grain, p * grain_scale).r;
	float fade = 1.0 - smoothstep(25.0, 70.0, length(VERTEX));
	float line = (grid(p, 1.0, 1.0) * 0.5 + grid(p, 5.0, 1.5)) * lines * fade;

	float puddle = 0.0;
	if (wetness > 0.001) {
		vec2 q = vec2(p.x * 0.22, p.y * 0.55);
		float soak = value_noise(q) * 0.65 + value_noise(q * 2.7 + 7.1) * 0.35;
		float edge = 0.74 - wetness * 0.3;
		puddle = smoothstep(edge, edge + 0.07, soak);
	}
	float damp = wetness * 0.4 + puddle * 0.6;

	vec3 albedo = tint.rgb * (0.55 + base * 0.9) * (1.0 - 0.7 * damp);
	ALBEDO = albedo;
	ROUGHNESS = mix(0.45, 0.07, damp);
	SPECULAR = mix(0.4, 0.9, damp);

	vec3 view = normalize(world - CAMERA_POSITION_WORLD);
	vec3 bounce = vec3(view.x, -view.y, view.z);
	float reach = (wall_z - world.z) / min(bounce.z, -0.001);
	vec3 hit = world + bounce * max(reach, 0.0);
	float cos_view = clamp(-view.y, 0.0, 1.0);
	float fresnel = 0.04 + 0.96 * pow(1.0 - cos_view, 5.0);
	float mirrored = (mirror_base + wall_pool(hit.xy) * mirror_gain) * fresnel * gloss * (1.0 + puddle * 3.0 + wetness * 0.3);

	EMISSION = glow.rgb * (albedo * pool * lit + vec3(mirrored) + vec3(line * 0.05 * (0.3 + pool)));

	float side = 1.0 - step(0.5, up.y);
	ALBEDO = mix(ALBEDO, vec3(0.0), side);
	EMISSION *= 1.0 - side;
	SPECULAR *= 1.0 - side;
}
