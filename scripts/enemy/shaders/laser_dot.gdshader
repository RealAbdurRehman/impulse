shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled;

uniform float strength = 1.0;
uniform vec3 core : source_color = vec3(1.0, 0.88, 0.82);
uniform vec3 glow : source_color = vec3(1.0, 0.06, 0.03);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float level = mix(0.25, 1.0, pow(strength, 1.2));
	float warn = smoothstep(0.78, 0.95, strength);
	float pulse = mix(0.92, 0.6 + 0.4 * step(0.0, sin(TIME * (22.0 + strength * 26.0))), warn);

	float centre = exp(-pow(r / 0.075, 2.0));
	float halo = exp(-pow(r / 0.3, 2.0));
	float ring_at = mix(0.95, 0.3, smoothstep(0.0, 1.0, strength));
	float ring = exp(-pow((r - ring_at) / 0.04, 2.0)) * smoothstep(0.1, 0.6, strength) * (1.0 - smoothstep(0.85, 1.0, r));

	vec3 colour = mix(glow, core, clamp(centre * 1.2, 0.0, 1.0));
	float alpha = clamp(centre + halo * 0.45 + ring * 0.9, 0.0, 1.0) * level * pulse;
	ALBEDO = colour * mix(1.0, 1.4, centre);
	ALPHA = alpha;
}
