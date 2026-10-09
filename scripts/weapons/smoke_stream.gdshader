shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.8, 0.84, 0.92);
uniform vec3 warm : source_color = vec3(1.0, 0.86, 0.68);
uniform vec2 noise_freq = vec2(3.0, 6.5);
uniform float flow = 0.3;

void fragment() {
	float age = COLOR.r;
	float seed = COLOR.g;

	vec2 p = UV * 2.0 - 1.0;
	vec2 local = p * vec2(UV2.x, COLOR.b * 0.25) * 0.5;
	vec2 uv = (vec2(UV2.y, 0.0) + local) * noise_freq;
	uv += vec2(seed * 7.3 - flow * age, seed * 3.1);

	vec2 warp = vec2(
		textureLod(noise_tex, uv * 0.6 + 0.21, 2.0).r,
		textureLod(noise_tex, uv * 0.6 + 0.67, 2.0).r
	) - 0.5;
	vec2 q = uv + warp * (0.15 + age * 0.5);

	float n1 = textureLod(noise_tex, q, 1.6).r;
	float n2 = textureLod(noise_tex, q * 1.8 + seed, 2.2).r;

	float env = 1.0 - smoothstep(0.15, 1.0, length(p) + (n1 - 0.5) * (0.3 + age * 0.7));
	env *= env;

	float body = smoothstep(0.12 + age * 0.12, 0.9, n1 * 0.75 + n2 * 0.25);

	ALBEDO = mix(warm, tint, smoothstep(0.0, 0.06, age));
	ALPHA = clamp(env * body * COLOR.a, 0.0, 1.0);
}