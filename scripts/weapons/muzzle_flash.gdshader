shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 core_color : source_color = vec3(1.0, 1.0, 0.97);
uniform vec3 rim_color : source_color = vec3(1.0, 0.6, 0.4);
uniform vec2 seed = vec2(0.0);
uniform float level = 1.0;
uniform float age = 0.0;
uniform float fade = 0.0;
uniform float lobes = 0.12;
uniform float taper = 0.3;
uniform float shift = 0.0;
uniform float squareness = 2.5;
uniform float glow = 0.12;

const float G = 1.7;

void fragment() {
	vec2 p = (UV * 2.0 - 1.0) * G / mix(0.85, 1.1, age);
	p.x -= shift;

	float tp = 1.0 - taper * clamp(p.x, 0.0, 1.0);
	float n1 = textureLod(noise_tex, p * 0.2 + seed, 3.0).r - 0.5;
	float n2 = textureLod(noise_tex, p * 0.4 + seed.yx + age * 0.2, 3.5).r - 0.5;

	float d = pow(pow(abs(p.x), squareness) + pow(abs(p.y) / tp, squareness), 1.0 / squareness);
	d += n1 * lobes * 2.0 + n2 * lobes;
	d += fade * 0.55;

	float body = 1.0 - smoothstep(0.7, 1.0, d);
	float hot = 1.0 - smoothstep(0.38, 0.96, d);
	float halo = exp(-pow(max(d - 0.7, 0.0) * 2.2, 2.0)) * glow * (1.0 - smoothstep(1.2, G, d));

	vec3 col = mix(rim_color, core_color, smoothstep(0.0, 1.0, hot * 1.5)) * (1.0 + hot * 1.3);

	ALBEDO = col;
	ALPHA = max(body, halo) * level;
}