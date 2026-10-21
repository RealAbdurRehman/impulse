shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;

const int MAX_WOUNDS = 12;

uniform float clock = 0.0;
uniform float fade = 1.0;
uniform vec3 glow : source_color = vec3(0.06, 0.05, 0.035);
uniform mat4 to_bone;
uniform int wound_count = 0;
uniform vec4 wound_pos[12];
uniform vec4 wound_info[12];
uniform vec3 fresh : source_color = vec3(0.3, 0.01, 0.016);
uniform vec3 dried : source_color = vec3(0.3, 0.13, 0.08);

varying vec3 v_pos;
varying vec3 v_nrm;
varying vec3 v_down;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

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
	mat3 to_b = mat3(to_bone);
	v_pos = (to_bone * vec4(VERTEX, 1.0)).xyz;
	v_nrm = normalize(to_b * NORMAL);
	v_down = normalize(to_b * (transpose(mat3(MODEL_MATRIX)) * vec3(0.0, -1.0, 0.0)));
	VERTEX += NORMAL * 0.0012;
}

void fragment() {
	float n = noise3(v_pos * 60.0) * 0.6 + noise3(v_pos * 150.0) * 0.4;
	vec3 slide = v_down - v_nrm * dot(v_down, v_nrm);
	float sl = length(slide);
	vec3 run = sl > 0.001 ? slide / sl : vec3(0.0, -1.0, 0.0);
	vec3 side = cross(v_nrm, run);
	float runs = smoothstep(0.2, 0.65, sl);

	float mask = 0.0;
	float wet = 0.0;
	float core = 0.0;
	for (int i = 0; i < MAX_WOUNDS; i++) {
		if (i >= wound_count) {
			break;
		}
		vec4 wp = wound_pos[i];
		vec4 wi = wound_info[i];
		float age = max(clock - wi.x, 0.0);
		vec3 d = v_pos - wp.xyz;
		float rad = wp.w * (0.4 + 0.6 * (1.0 - exp(-age * 7.0))) * (1.0 + 0.35 * (1.0 - exp(-age * 0.2)));
		float dist = length(d) * (0.74 + 0.55 * n);
		float blob = 1.0 - smoothstep(rad * 0.65, rad, dist);
		float centre = 1.0 - smoothstep(0.0, rad, dist);

		float streak = 0.0;
		float len = wi.z * (1.0 - exp(-age * wi.w));
		if (len > 0.004 && runs > 0.0) {
			float along = dot(d, run);
			float lat = dot(d, side);
			for (int k = 0; k < 3; k++) {
				float fk = float(k);
				float off = (fk - 1.0) * rad * 0.55 + (hash11(wi.y + fk * 3.7) - 0.5) * rad * 0.5;
				float lk = len * (0.5 + 0.5 * hash11(wi.y * 5.0 + fk * 9.1));
				float wob = (noise3(vec3(along * 28.0, wi.y * 10.0 + fk, 0.0)) - 0.5) * 0.007;
				float w = 0.0042 * (1.0 - 0.45 * clamp(along / max(lk, 0.001), 0.0, 1.0)) * (0.7 + 0.6 * hash11(wi.y * 3.0 + fk));
				float s = 1.0 - smoothstep(w * 0.55, w, abs(lat - off - wob));
				s *= smoothstep(-0.004, 0.008, along) * (1.0 - smoothstep(lk - 0.006, lk, along));
				float bead = 1.0 - smoothstep(w * 1.1, w * 1.9, length(vec2(lat - off - wob, along - lk)));
				streak = max(streak, max(s, bead));
			}
			streak *= runs;
		}

		float here = max(blob, streak);
		float dry = smoothstep(15.0, 255.0, age) * 0.85;
		wet = max(wet, here * (1.0 - dry));
		mask = max(mask, here);
		core = max(core, centre * blob);
	}

	vec3 col = mix(dried, fresh, wet);
	col *= (0.78 + 0.5 * n) * mix(1.0, 0.62, core);
	ALBEDO = col;
	ALPHA = clamp(mask, 0.0, 1.0) * 0.94 * fade;
	ROUGHNESS = mix(0.8, 0.28, wet);
	SPECULAR = mix(0.2, 0.65, wet);
	EMISSION = col * mix(0.1, 0.18, wet) + glow * (1.0 - wet) * mask;
}
