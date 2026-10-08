shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.78, 0.82, 0.9);
uniform vec2 seed = vec2(0.0);
uniform float length_scale = 1.6;

void fragment() {
	float across = abs(UV.x * 2.0 - 1.0);
	float env = 1.0 - smoothstep(0.0, 1.0, across);
	env = env * env;

	vec2 uv = vec2(UV.x * 0.55 + seed.x, UV.y * length_scale + seed.y);
	float n1 = textureLod(noise_tex, uv, 1.4).r;
	float n2 = textureLod(noise_tex, vec2(uv.x * 1.9 + 0.37, uv.y * 2.2 - seed.x), 1.9).r;
	float body = smoothstep(0.18, 0.82, n1 * 0.7 + n2 * 0.3);

	ALBEDO = tint;
	ALPHA = clamp(env * body * COLOR.a, 0.0, 1.0);
}