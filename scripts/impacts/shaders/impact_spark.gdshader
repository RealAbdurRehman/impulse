shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

varying vec4 v_col;
varying float v_round;

void vertex() {
	v_col = COLOR;
	v_round = INSTANCE_CUSTOM.x;
}

void fragment() {
	float across = abs(UV.y * 2.0 - 1.0);
	float line = pow(1.0 - across, 2.0);
	float tail = pow(UV.x, 2.0);
	float streak = line * tail;

	vec2 q = UV * 2.0 - 1.0;
	float glow = pow(max(1.0 - length(q), 0.0), 2.0);

	float v = mix(streak, glow, v_round);
	float hot = mix(pow(UV.x, 5.0) * line, glow * glow, v_round);
	vec3 col = mix(v_col.rgb, vec3(1.0, 0.95, 0.85), hot);

	ALBEDO = col * v * v_col.a * 2.2;
	ALPHA = 1.0;
}
