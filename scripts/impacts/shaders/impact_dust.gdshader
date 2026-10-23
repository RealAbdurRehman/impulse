shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec2 noise_scale = vec2(0.5, 0.5);
uniform vec2 flow = vec2(0.3, 0.05);

varying vec4 v_data;
varying vec4 v_tint;

void vertex() {
	v_data = INSTANCE_CUSTOM;
	v_tint = COLOR;
}

void fragment() {
	float age = v_data.x;
	vec2 seed = v_data.yz;
	float grain = v_data.w;

	float along = UV.x;
	float girth = mix(0.3, 1.0, smoothstep(0.0, 0.4, along)) * mix(1.0, 0.45, smoothstep(0.55, 1.0, along));
	float across = abs(UV.y * 2.0 - 1.0) / girth;
	float env_y = 1.0 - smoothstep(0.0, 1.0, across);
	float env = env_y * env_y * smoothstep(0.0, 0.03, along) * (1.0 - smoothstep(0.35, 1.0, along));

	vec2 uv = UV * noise_scale + seed + flow * age;
	float n1 = textureLod(noise_tex, uv, 1.2).r;
	float n2 = textureLod(noise_tex, uv * 1.8 + seed.yx + flow * age * 0.8, 1.8).r;
	float n3 = textureLod(noise_tex, uv * 5.0 + seed, 0.6).r;
	float cloud = mix(n1 * 0.75 + n2 * 0.25, n1 * 0.55 + n2 * 0.2 + n3 * 0.25, grain);
	float body = smoothstep(0.1, 0.8, cloud);

	float life = smoothstep(0.0, 0.05, age) * (1.0 - smoothstep(0.15, 1.0, age));

	ALBEDO = v_tint.rgb * mix(0.88, 1.08, n1);
	ALPHA = clamp(env * body * v_tint.a * life, 0.0, 1.0);
}
