shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_disabled;

varying vec4 v_data;
varying vec4 v_col;

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise2(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 x) {
	return noise2(x) * 0.5 + noise2(x * 2.1 + 7.3) * 0.3 + noise2(x * 4.3 + 1.7) * 0.2;
}

void vertex() {
	v_data = INSTANCE_CUSTOM;
	v_col = COLOR;
}

void fragment() {
	float seed = v_data.x;
	int kind = int(v_data.y + 0.5);
	float glance = v_data.z;

	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec2 dir = p / max(r, 0.0001);
	vec2 off = vec2(seed * 13.1, seed * 7.7);
	float wob = fbm(p * 3.0 + off) - 0.5;
	float rw = r + wob * 0.3;
	float ray = noise2(dir * 3.2 + off);

	vec3 spall = v_col.rgb;
	vec3 col = spall;
	float a = 0.0;

	if (kind == 1 || kind == 2 || kind == 6) {
		float reach = kind == 6 ? 0.95 : 0.8;
		float crater = kind == 6 ? 0.2 : 0.3;
		float halo_r = reach * (0.4 + 0.75 * ray);
		float halo = 1.0 - smoothstep(0.08, halo_r, r + wob * 0.12);
		float pit = 1.0 - smoothstep(crater * 0.55, crater, rw);
		float core = 1.0 - smoothstep(0.07, 0.13, rw);
		float grit = noise2(p * 22.0 + off);
		col = mix(spall * (0.85 + 0.3 * grit), spall * 0.22, pit);
		col = mix(col, vec3(0.02), core);
		a = max(halo * (kind == 6 ? 0.78 : 0.55), pit * 0.85);
		a = max(a, core);
	} else if (kind == 3) {
		float core = 1.0 - smoothstep(0.11, 0.17, rw);
		float dent = 1.0 - smoothstep(0.16, 0.34, rw);
		float rim = smoothstep(0.1, 0.24, rw) * (1.0 - smoothstep(0.3, 0.42, rw));
		float smear = exp(-pow(p.y / 0.1, 2.0)) * smoothstep(0.05, 0.5, p.x) * (1.0 - smoothstep(0.65, 1.0, p.x));
		smear *= glance * (0.6 + 0.8 * noise2(vec2(p.x * 9.0, seed * 20.0)));
		col = mix(vec3(0.3, 0.3, 0.32), spall, rim);
		col = mix(col, vec3(0.025), core);
		a = max(max(rim * 0.85, dent * 0.5), core);
		a = max(a, smear * 0.7);
	} else if (kind == 4) {
		vec2 e = vec2(p.x * 0.62, p.y * 1.25);
		float er = length(e) + wob * 0.2;
		float fibre = noise2(vec2(p.x * 2.5 + off.x, p.y * 20.0));
		float halo = (1.0 - smoothstep(0.15, 0.85, er)) * smoothstep(0.25, 0.75, fibre + (1.0 - er) * 0.3);
		float core = 1.0 - smoothstep(0.13, 0.2, rw);
		col = mix(spall * (0.7 + 0.5 * fibre), vec3(0.05, 0.032, 0.02), core);
		a = max(halo * 0.8, core);
	} else if (kind == 5) {
		float n = 11.0;
		float ang = atan(p.y, p.x) / 6.2831853 + 0.5;
		float cell = floor(ang * n);
		float jit = hash21(vec2(cell, seed * 31.0));
		float d = abs(fract(ang * n) - 0.5 - (jit - 0.5) * 0.35);
		float width = 0.05 + 0.5 / (r * 40.0 + 6.0);
		float reachr = 0.45 + 0.5 * hash21(vec2(cell + 3.0, seed * 17.0));
		float line = (1.0 - smoothstep(width * 0.5, width, d)) * (1.0 - smoothstep(reachr - 0.15, reachr, r));
		float ringd = abs(fract(r * 3.4 + wob * 0.5) - 0.5);
		float ring = (1.0 - smoothstep(0.02, 0.06, ringd)) * smoothstep(0.4, 0.6, noise2(dir * 4.0 + off)) * (1.0 - smoothstep(0.55, 0.85, r)) * step(0.22, r);
		float haze = (1.0 - smoothstep(0.0, 0.3, r)) * 0.35;
		float hole = 1.0 - smoothstep(0.05, 0.1, rw);
		col = spall;
		a = max(max(line * 0.8, ring * 0.6), haze) * (1.0 - hole);
	} else if (kind == 7) {
		float pit = (1.0 - smoothstep(0.0, 0.5, rw)) * 0.7;
		float loose = 1.0 - smoothstep(0.15, 0.95 * (0.45 + 0.75 * ray), r + wob * 0.15);
		float grains = step(0.64, noise2(p * 30.0 + off)) * loose;
		col = mix(spall * 1.18, spall * 0.4, pit / 0.7);
		a = max(pit, loose * 0.16 + grains * 0.35);
	}

	a *= 1.0 - smoothstep(0.82, 1.0, r);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	ALPHA = clamp(a * v_col.a, 0.0, 1.0);
}
