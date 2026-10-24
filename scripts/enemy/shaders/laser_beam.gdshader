shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled;

uniform float strength = 1.0;
uniform float length_m = 10.0;
uniform float width_m = 0.1;
uniform float seed = 0.0;
uniform vec3 core : source_color = vec3(1.0, 0.85, 0.8);
uniform vec3 glow : source_color = vec3(1.0, 0.06, 0.03);

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float vnoise(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash11(i), hash11(i + 1.0), f);
}

void fragment() {
	float along = UV.x * length_m;
	float d = abs(UV.y * 2.0 - 1.0) * width_m * 0.5;
	float px = fwidth(d);

	float core_sigma = max(0.0022 * mix(1.5, 0.8, strength), px * 0.85);
	float glow_sigma = max(0.016 * mix(1.4, 0.9, strength), px * 3.0);
	float core_term = exp(-pow(d / core_sigma, 2.0));
	float glow_term = exp(-pow(d / glow_sigma, 2.0));

	float level = mix(0.16, 1.0, pow(strength, 1.3));
	float warn = smoothstep(0.78, 0.95, strength);
	float blink = mix(1.0, 0.55 + 0.45 * step(0.0, sin(TIME * (22.0 + strength * 26.0))), warn);

	float dust = 0.72 + 0.5 * vnoise(along * 7.0 - TIME * 1.6 + seed) + 0.25 * vnoise(along * 19.0 + TIME * 2.3 + seed * 2.0);

	float fade_in = smoothstep(0.0, 0.35, along);
	float fade_far = mix(1.0, 0.6, clamp(along / 45.0, 0.0, 1.0));

	vec3 colour = glow * glow_term * 0.7 + core * core_term * 1.1;
	ALBEDO = colour * level * blink * dust * fade_in * fade_far;
	ALPHA = 1.0;
}
