shader_type canvas_item;

uniform float fade = 0.0;
uniform float gauge = 0.0;
uniform float bang = 0.0;
uniform float age = 9.0;
uniform float seed = 0.0;
uniform float marked = 1.0;
uniform vec2 direction = vec2(-1.0, 0.0);

const float EXTENT = 1.1;
const float LOW = -0.42;
const float HIGH = 0.58;
const vec3 CALM = vec3(0.86, 0.84, 0.74);
const vec3 WARM = vec3(0.88, 0.62, 0.14);
const vec3 HOT = vec3(0.78, 0.15, 0.1);
const vec3 FLASH = vec3(0.96, 0.93, 0.84);
const vec3 INK = vec3(0.02, 0.02, 0.02);

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

float triangle(vec2 p, vec2 p0, vec2 p1, vec2 p2) {
	vec2 e0 = p1 - p0;
	vec2 e1 = p2 - p1;
	vec2 e2 = p0 - p2;
	vec2 v0 = p - p0;
	vec2 v1 = p - p1;
	vec2 v2 = p - p2;
	vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
	vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
	vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
	float s = sign(e0.x * e2.y - e0.y * e2.x);
	vec2 d = min(min(vec2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)), vec2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))), vec2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
	return -sqrt(d.x) * sign(d.y);
}

float question(vec2 p) {
	float d = arc(p, vec2(0.0, 0.3), 0.22, radians(-70.0), radians(200.0), 0.07);
	d = min(d, box(p, vec2(0.07, 0.1)));
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
	vec2 whole = (UV - 0.5) * 2.0 * EXTENT;
	whole.y = -whole.y;
	vec2 p = whole;
	p.y += 0.07;

	float jolt = bang * exp(-age * 7.0) * 0.06;
	p += vec2(hash(vec2(tick, 1.0)) - 0.5, hash(vec2(tick, 2.0)) - 0.5) * jolt * 2.0;

	float soft = max(fwidth(p.x), 0.002);
	float level = mix(gauge, 1.0, bang);
	vec3 tint = level < 0.5 ? mix(CALM, WARM, level * 2.0) : mix(WARM, HOT, (level - 0.5) * 2.0);
	tint = mix(tint, FLASH, bang * step(age, 0.1));

	vec2 way = normalize(vec2(direction.x, -direction.y));
	vec2 side = vec2(-way.y, way.x);
	float pointer = triangle(whole, way * 0.88, way * 0.56 + side * 0.2, way * 0.56 - side * 0.2);
	float pointer_shadow = triangle(whole - vec2(0.035, -0.045), way * 0.88, way * 0.56 + side * 0.2, way * 0.56 - side * 0.2);

	float glyph = mix(question(p), exclaim(p), bang);
	float shadow = mix(question(p - vec2(0.035, -0.045)), exclaim(p - vec2(0.035, -0.045)), bang);

	float filled = smoothstep(mix(LOW, HIGH, level) + 0.02, mix(LOW, HIGH, level) - 0.02, p.y) * step(0.01, level);
	filled = max(filled, step(0.99, level));
	float grain = 1.0 - 0.16 * step(0.82, hash(floor(whole * 24.0) + tick));

	float glyph_body = cover(glyph, soft) * mix(0.4, 1.0, filled) * grain * marked;
	float pointer_body = cover(pointer, soft) * grain;
	float edge = max(cover(glyph - 0.014, soft) * marked, cover(pointer - 0.014, soft));
	float cast = max(cover(shadow, soft * 6.0) * marked, cover(pointer_shadow, soft * 6.0));

	vec3 glyph_colour = mix(CALM, tint, filled);
	float body = max(glyph_body, pointer_body);
	vec3 colour = pointer_body > glyph_body ? tint : glyph_colour;
	float ink = max(cast * 0.45, edge * 0.85);

	float alpha = body + ink * (1.0 - body);
	vec3 rgb = (colour * body + INK * ink * (1.0 - body)) / max(alpha, 0.0001);

	COLOR = vec4(rgb, alpha * fade);
}
