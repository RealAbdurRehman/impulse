shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.07, 0.055, 0.045, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.55;

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

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float wobble = noise(p * 2.6 + vec2(3.1, 7.7)) * 0.55 + noise(p * 6.0) * 0.25;
	float edge = 1.0 - smoothstep(0.15, 0.95, length(p) + wobble * 0.5 - 0.25);
	ALBEDO = tint.rgb;
	ALPHA = clamp(edge, 0.0, 1.0) * strength;
}
