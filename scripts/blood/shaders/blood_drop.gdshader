shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform;

uniform vec3 deep : source_color = vec3(0.17, 0.004, 0.007);
uniform vec3 bright : source_color = vec3(0.44, 0.018, 0.024);
uniform vec3 glint : source_color = vec3(1.0, 0.5, 0.45);

varying vec4 v_col;

void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 along = MODEL_MATRIX[0].xyz;
	float len = length(along);
	float wid = length(MODEL_MATRIX[1].xyz);
	vec3 axis = along / max(len, 0.0001);
	vec3 to_cam = normalize(INV_VIEW_MATRIX[3].xyz - centre);
	vec3 side = normalize(cross(axis, to_cam));
	vec3 world = centre + axis * VERTEX.x * len + side * VERTEX.y * wid;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	v_col = COLOR;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float w = mix(0.55, 1.0, smoothstep(-1.0, 0.35, p.x));
	float shape = (1.0 - smoothstep(0.7, 1.0, abs(p.y) / w)) * (1.0 - smoothstep(0.78, 1.0, abs(p.x)));
	float round_ = sqrt(max(1.0 - p.y * p.y, 0.0));
	vec3 col = mix(deep, bright, round_ * v_col.r);
	col += glint * pow(max(1.0 - length(p - vec2(0.1, -0.4)) / 0.5, 0.0), 2.0) * 0.45;
	ALBEDO = col;
	ALPHA = shape * v_col.a;
}
