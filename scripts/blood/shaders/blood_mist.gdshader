shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.34, 0.012, 0.02);

varying vec4 v_data;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
	v_data = INSTANCE_CUSTOM;
}

void fragment() {
	float age = v_data.x;
	float seed = v_data.y;
	float density = v_data.z;
	vec2 p = UV * 2.0 - 1.0;
	float env = 1.0 - smoothstep(0.1, 1.0, length(p));
	env *= env;
	vec2 uv = UV * 0.8 + vec2(seed, seed * 1.7) + vec2(age * 0.12, -age * 0.06);
	float n1 = textureLod(noise_tex, uv, 1.0).r;
	float n2 = textureLod(noise_tex, uv * 2.3 + 0.37, 1.5).r;
	float body = smoothstep(0.22 + age * 0.3, 0.7, n1 * 0.65 + n2 * 0.35);
	float life = smoothstep(0.0, 0.05, age) * (1.0 - smoothstep(0.3, 1.0, age));
	ALBEDO = tint * (0.6 + 0.8 * n1);
	ALPHA = clamp(env * body * density * life, 0.0, 0.62);
}
