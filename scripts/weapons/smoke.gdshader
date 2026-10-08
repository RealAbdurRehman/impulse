shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.8, 0.84, 0.92);
uniform vec3 warm : source_color = vec3(1.0, 0.86, 0.68);
uniform vec2 seed = vec2(0.0);
uniform vec2 noise_scale = vec2(1.2, 0.9);
uniform vec2 flow = vec2(0.3, 0.0);
uniform float density = 0.3;
uniform float age = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float env = 1.0 - smoothstep(0.15, 1.0, length(p));
	env *= env;

	vec2 uv = UV * noise_scale + seed + flow * age;
	float n1 = textureLod(noise_tex, uv, 1.2).r;
	float n2 = textureLod(noise_tex, uv * 1.8 + seed.yx + flow * age * 0.8, 1.8).r;
	float body = smoothstep(0.12, 0.9, n1 * 0.75 + n2 * 0.25);

	float life = smoothstep(0.0, 0.07, age) * (1.0 - smoothstep(0.2, 1.0, age));

	ALBEDO = mix(warm, tint, smoothstep(0.0, 0.25, age));
	ALPHA = clamp(env * body * density * life, 0.0, 1.0);
}