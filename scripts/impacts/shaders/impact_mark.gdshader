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
	vec2 off = vec2(seed * 13.1, seed * 7.7);
	float wob = fbm(p * 4.0 + off) - 0.5;
	float rw = r + wob * 0.14;
	float ray = noise2(normalize(p + 0.0001) * 3.0 + off);

	vec3 spall = v_col.rgb;
	vec3 col = spall;
	float a = 0.0;
	float hole = 1.0 - smoothstep(0.2, 0.26, rw);

	if (kind == 1) {
		float chip = (1.0 - smoothstep(0.26, 0.42 + 0.2 * ray, rw)) * 0.9;
		float scuff = (1.0 - smoothstep(0.2, 0.8 * (0.5 + 0.6 * ray), r)) * 0.3 * (0.6 + 0.8 * noise2(p * 18.0 + off));
		col = mix(spall, vec3(0.03), hole);
		a = max(max(chip, scuff), hole);
	} else if (kind == 2) {
		float rim = smoothstep(0.2, 0.3, rw) * (1.0 - smoothstep(0.34, 0.46, rw));
		float smear = exp(-pow(p.y / 0.1, 2.0)) * smoothstep(0.1, 0.5, p.x) * (1.0 - smoothstep(0.6, 1.0, p.x)) * glance;
		col = mix(spall, vec3(0.03), hole);
		a = max(max(rim * 0.9, smear * 0.6), hole);
	} else if (kind == 3) {
		vec2 e = vec2(p.x * 0.7, p.y * 1.3);
		float er = length(e) + wob * 0.12;
		float fibre = noise2(vec2(p.x * 3.0 + off.x, p.y * 22.0));
		float halo = (1.0 - smoothstep(0.24, 0.8, er)) * smoothstep(0.3, 0.75, fibre + 0.3);
		col = mix(spall * (0.75 + 0.5 * fibre), vec3(0.04, 0.025, 0.015), hole);
		a = max(halo * 0.75, hole);
	} else if (kind == 4) {
		float n = 9.0;
		float ang = atan(p.y, p.x) / 6.2831853 + 0.5;
		float cell = floor(ang * n);
		float jit = hash21(vec2(cell, seed * 31.0));
		float d = abs(fract(ang * n) - 0.5 - (jit - 0.5) * 0.3);
		float reach = 0.4 + 0.5 * hash21(vec2(cell + 3.0, seed * 17.0));
		float width = 0.04 + 0.25 / (r * 30.0 + 5.0);
		float line = (1.0 - smoothstep(width * 0.5, width, d)) * (1.0 - smoothstep(reach - 0.15, reach, r));
		float tiny = 1.0 - smoothstep(0.04, 0.08, rw);
		a = max(line * 0.85, (1.0 - smoothstep(0.0, 0.25, r)) * 0.3) * (1.0 - tiny);
	}

	a *= 1.0 - smoothstep(0.85, 1.0, r);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	ALPHA = clamp(a * v_col.a, 0.0, 1.0);
}
