shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx, shadows_disabled;

varying vec4 v_col;

void vertex() {
	v_col = COLOR;
}

void fragment() {
	ALBEDO = v_col.rgb;
	EMISSION = v_col.rgb * 0.22;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
}
