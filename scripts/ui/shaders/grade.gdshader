shader_type canvas_item;
render_mode unshaded;

uniform float vignette : hint_range(0.0, 1.0) = 0.6;
uniform float grain : hint_range(0.0, 0.2) = 0.085;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 centred = UV - 0.5;
	float edge = smoothstep(0.25, 0.85, length(centred * vec2(1.2, 1.0)));
	float noise = hash(floor(FRAGCOORD.xy * 0.5) + floor(TIME * 24.0) * 17.0) - 0.5;
	float dark = edge * vignette;
	COLOR = vec4(vec3(noise * grain), 0.0);
	COLOR.rgb = mix(COLOR.rgb, vec3(0.0), dark);
	COLOR.a = clamp(dark + abs(noise) * grain * 2.0, 0.0, 1.0);
}
