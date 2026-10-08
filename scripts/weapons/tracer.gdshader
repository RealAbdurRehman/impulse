shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 core_color : source_color = vec3(1.0, 0.97, 0.85);
uniform vec3 glow_color : source_color = vec3(1.0, 0.55, 0.22);
uniform vec2 seed = vec2(0.0);
uniform float length_m = 3.0;
uniform float scroll = 0.0;
uniform float level = 1.0;

void fragment() {
	float u = UV.x;
	float v = abs(UV.y * 2.0 - 1.0);
	float px = fwidth(UV.y) * 2.0;

	float tip = 1.0 - smoothstep(0.86, 1.0, u);
	float trail = pow(smoothstep(0.0, 1.0, u), 1.3);
	float env = trail * tip;

	float wob = textureLod(noise_tex, vec2(u * length_m * 0.6 + seed.y, seed.x), 2.5).r;
	float flick = textureLod(noise_tex, vec2(u * length_m * 1.1 + seed.x, seed.y + scroll), 2.0).r;

	float shape = mix(0.3, 1.0, pow(u, 0.6)) * (0.9 + 0.2 * wob);
	float core_w = max(0.4 * shape, px * 1.4);
	float glow_w = max(0.95 * shape, px * 2.6);

	float core = exp(-pow(v / core_w, 2.0)) * min(1.0, 0.4 * shape / core_w);
	float glow = exp(-pow(v / glow_w, 2.0)) * min(1.0, 0.95 * shape / glow_w);

	float brightness = mix(0.7, 1.0, smoothstep(0.2, 0.8, flick));
	float hot = clamp(core * (0.35 + 0.65 * smoothstep(0.2, 1.0, u)) * 1.3, 0.0, 1.0);

	ALBEDO = mix(glow_color, core_color, hot);
	ALPHA = clamp((core * 0.95 + glow * 0.45) * env * brightness, 0.0, 1.0) * level;
}