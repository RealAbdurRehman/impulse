shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled;

uniform float fade = 0.0;
uniform float open = 1.0;
uniform float hidden = 0.0;
uniform float exposure = 0.0;
uniform float alert = 0.0;
uniform float seed = 0.0;

const float EXTENT = 1.0;
const float WIDTH = 0.84;
const float STROKE = 0.07;
const vec3 CALM = vec3(0.86, 0.84, 0.74);
const vec3 WARM = vec3(0.88, 0.62, 0.14);
const vec3 HOT = vec3(0.78, 0.15, 0.1);
const vec3 INK = vec3(0.02, 0.02, 0.02);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float lens(vec2 p, float half_height) {
	float r = (WIDTH * WIDTH + half_height * half_height) / (2.0 * half_height);
	float upper = length(p - vec2(0.0, half_height - r)) - r;
	float lower = length(p - vec2(0.0, r - half_height)) - r;
	return max(upper, lower);
}

float segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

float cover(float d, float soft) {
	return 1.0 - smoothstep(-soft, soft, d);
}

void fragment() {
	float tick = floor(TIME * 9.0) + seed;
	vec2 p = (UV - 0.5) * 2.0 * EXTENT;
	p.y = -p.y;
	float soft = max(fwidth(p.x), 0.002);

	float half_height = mix(0.045, 0.4, open) * (1.0 - hidden * 0.9);
	float shape = lens(p, half_height);
	float outline = abs(shape) - STROKE * 0.5;
	float pupil_size = 0.24 * smoothstep(0.12, 0.45, open) * (1.0 - hidden);
	float pupil = max(length(p) - pupil_size, shape + STROKE * 0.5);
	float slash = segment(p, vec2(-0.3, 0.26), vec2(0.3, -0.26)) - STROKE * 0.5;
	slash = mix(1.0, slash, hidden);

	float body_d = min(min(outline, pupil), slash);
	float shadow_d = min(min(abs(lens(p - vec2(0.03, -0.045), half_height)) - STROKE * 0.5, length(p - vec2(0.03, -0.045)) - pupil_size), mix(1.0, segment(p - vec2(0.03, -0.045), vec2(-0.3, 0.26), vec2(0.3, -0.26)) - STROKE * 0.5, hidden));

	vec3 tint = mix(CALM, WARM, smoothstep(0.3, 0.95, exposure));
	tint = mix(tint, HOT, alert);
	tint *= mix(1.0, 0.72, hidden);

	float grain = 1.0 - 0.16 * step(0.82, hash(floor(p * 40.0) + tick));
	float body = cover(body_d, soft) * grain;
	float edge = cover(body_d - 0.018, soft);
	float cast = cover(shadow_d, soft * 6.0);

	float ink = max(cast * 0.45, edge * 0.85);
	float alpha = body + ink * (1.0 - body);
	vec3 rgb = (tint * body + INK * ink * (1.0 - body)) / max(alpha, 0.0001);

	ALBEDO = rgb;
	ALPHA = alpha * fade * mix(1.0, 0.75, hidden);
}
