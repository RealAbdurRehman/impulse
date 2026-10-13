shader_type spatial;
render_mode cull_front, unshaded, skip_vertex_transform;

uniform vec4 color : source_color = vec4(1.0);
uniform float width = 0.008;
uniform float push = 0.03;

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 grown = VERTEX + NORMAL * width / s;
	VERTEX = (MODELVIEW_MATRIX * vec4(grown, 1.0)).xyz;
	VERTEX.z -= push;
}

void fragment() {
	ALBEDO = color.rgb;
}
