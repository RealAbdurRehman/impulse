shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled;

uniform float fade = 0.0;
uniform float gauge = 0.0;
uniform float bang = 0.0;
uniform float age = 9.0;
uniform float seed = 0.0;

const float EXTENT = 0.85;
const float LOW = -0.42;
const float HIGH = 0.58;
const vec3 CALM = vec3(0.86, 0.84, 0.74);
const vec3 WARM = vec3(0.88, 0.62, 0.14);
const vec3 HOT = vec3(0.78, 0.15, 0.1);
const vec3 FLASH = vec3(0.96, 0.93, 0.84);
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

float box(vec2 p, vec2 half_size) {
	vec2 q = abs(p) - half_size;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

float taper(vec2 p, vec2 a, vec2 b, float ra, float rb) {
	vec2 ba = b - a;
	float h = clamp(dot(p - a, ba) / dot(ba, ba), 0.0, 1.0);
	return length(p - a - ba * h) - mix(ra, rb, h);
}

float arc(vec2 p, vec2 centre, float radius, float from, float to, float thickness) {
	vec2 q = p - centre;
	float mid = 0.5 * (from + to);
	float reach = 0.5 * (to - from);
	float turn = mod(atan(q.y, q.x) - mid + PI, TAU) - PI;
	float a = mid + clamp(turn, -reach, reach);
	return length(q - radius * vec2(cos(a), sin(a))) - thickness;
}

float question(vec2 p) {
	float d = arc(p, vec2(0.0, 0.3), 0.22, radians(-70.0), radians(200.0), 0.07);
	d = min(d, box(p - vec2(0.0, 0.0), vec2(0.07, 0.1)));
	return min(d, box(p - vec2(0.0, -0.34), vec2(0.08, 0.08)));
}

float exclaim(vec2 p) {
	float d = taper(p, vec2(0.0, 0.5), vec2(0.0, 0.06), 0.11, 0.065);
	return min(d, box(p - vec2(0.0, -0.33), vec2(0.085, 0.085)));
}

float cover(float d, float soft) {
	return 1.0 - smoothstep(-soft, soft, d);
}

void fragment() {
	float tick = floor(TIME * 9.0) + seed;
	vec2 p = (UV - 0.5) * 2.0 * EXTENT;
	p.y = -p.y;
	p.y += 0.07;

	float jolt = bang * exp(-age * 7.0) * 0.06;
	p += vec2(hash(vec2(tick, 1.0)) - 0.5, hash(vec2(tick, 2.0)) - 0.5) * jolt * 2.0;

	float soft = max(fwidth(p.x), 0.002);
	float level = mix(gauge, 1.0, bang);
	vec3 tint = level < 0.5 ? mix(CALM, WARM, level * 2.0) : mix(WARM, HOT, (level - 0.5) * 2.0);
	tint = mix(tint, FLASH, bang * step(age, 0.1));

	float glyph = mix(question(p), exclaim(p), bang);
	float shadow = mix(question(p - vec2(0.035, -0.045)), exclaim(p - vec2(0.035, -0.045)), bang);

	float filled = smoothstep(mix(LOW, HIGH, level) + 0.02, mix(LOW, HIGH, level) - 0.02, p.y) * step(0.01, level);
	filled = max(filled, step(0.99, level));
	float grain = 1.0 - 0.16 * step(0.82, hash(floor(p * 70.0) + tick));

	float body = cover(glyph, soft);
	float edge = cover(glyph - 0.014, soft);
	float cast = cover(shadow, soft * 6.0);

	vec3 colour = mix(CALM, tint, filled);
	float strength = mix(0.4, 1.0, filled);
	float alpha_ink = max(cast * 0.45, edge * 0.85);
	float alpha_body = body * strength * grain;

	float alpha = alpha_body + alpha_ink * (1.0 - alpha_body);
	vec3 rgb = (colour * alpha_body + INK * alpha_ink * (1.0 - alpha_body)) / max(alpha, 0.0001);

	ALBEDO = rgb;
	ALPHA = alpha * fade;
}
