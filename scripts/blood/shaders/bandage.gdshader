shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

uniform float clock = 0.0;
uniform float start = 0.0;
uniform float wrap_time = 2.6;
uniform float seed = 0.0;
uniform float height = 0.1;
uniform float turns = 1.0;
uniform vec3 soak_pos = vec3(0.0);
uniform float soak = 1.0;
uniform float soak_radius = 0.05;
uniform vec3 gauze : source_color = vec3(0.93, 0.89, 0.79);
uniform vec3 fresh : source_color = vec3(0.3, 0.01, 0.016);
uniform vec3 dried : source_color = vec3(0.3, 0.13, 0.08);

varying vec3 v_pos;

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash13(i), hash13(i + vec3(1.0, 0.0, 0.0)), f.x), mix(hash13(i + vec3(0.0, 1.0, 0.0)), hash13(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash13(i + vec3(0.0, 0.0, 1.0)), hash13(i + vec3(1.0, 0.0, 1.0)), f.x), mix(hash13(i + vec3(0.0, 1.0, 1.0)), hash13(i + vec3(1.0, 1.0, 1.0)), f.x), f.y),
		f.z);
}

void vertex() {
	v_pos = VERTEX;
}

void fragment() {
	float t = clamp((clock - start) / max(wrap_time, 0.01), 0.0, 1.0);
	t = t * t * (3.0 - 2.0 * t);
	float order = clamp(UV.x + (UV.y - 0.5) * 0.15, 0.0, 1.0);
	if (order > t * 1.1) {
		discard;
	}

	float n = noise3(v_pos * 190.0);
	float edge = abs(UV.y * 2.0 - 1.0) + (noise3(v_pos * 55.0 + seed) - 0.5) * 0.16;
	if (edge > 0.96) {
		discard;
	}

	float turn = fract(UV.y * height / 0.022 + UV.x * turns * 2.0 + seed);
	vec3 wrap = gauze * mix(0.66, 1.0, smoothstep(0.0, 0.14, turn)) * (0.9 + 0.12 * turn);
	wrap *= 0.93 + 0.14 * n;
	wrap *= 1.0 - 0.32 * smoothstep(0.68, 0.95, edge);

	float age = clock - start;
	float seep = smoothstep(0.0, 5.0, age - wrap_time);
	float spot = soak * seep * (1.0 - smoothstep(soak_radius * 0.3, soak_radius * 1.1, length(v_pos - soak_pos) + (noise3(v_pos * 70.0) - 0.5) * 0.024));
	vec3 stain = mix(dried * 0.85, fresh * 1.25, 1.0 - smoothstep(12.0, 170.0, age));
	wrap = mix(wrap, stain, clamp(spot, 0.0, 1.0) * 0.92);

	ALBEDO = wrap;
	ROUGHNESS = 0.95;
	SPECULAR = 0.08;
	EMISSION = wrap * 0.24;
}
