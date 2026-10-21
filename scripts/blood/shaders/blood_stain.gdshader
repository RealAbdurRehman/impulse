shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

uniform float clock = 0.0;
uniform vec3 fresh : source_color = vec3(0.34, 0.012, 0.018);
uniform vec3 dried : source_color = vec3(0.3, 0.13, 0.08);
uniform vec3 glow : source_color = vec3(0.06, 0.05, 0.035);
uniform float dry_delay = 15.0;
uniform float dry_time = 240.0;

varying vec4 v_data;
varying vec4 v_col;
varying vec2 v_size;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(float x, float period) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash11(mod(i, period)), hash11(mod(i + 1.0, period)), f);
}

float noise2(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	v_data = INSTANCE_CUSTOM;
	v_col = COLOR;
	v_size = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
}

void fragment() {
	float kind = v_data.z;
	float seed = v_data.y;
	float age = max(clock - v_data.x, 0.0);
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float u = atan(p.y, p.x) / 6.2831853 + 0.5;
	float mask = 0.0;
	float thick = 1.0;
	float rim = 1.0;
	float film = 1.15;
	float thin = 0.75;
	float edge_dist = 0.0;

	float dry = smoothstep(dry_delay, dry_delay + dry_time, age) * 0.85;
	vec3 tone = vec3(1.0);

	if (kind < 0.5) {
		float violence = v_data.w;
		float aspect = v_size.x / max(v_size.y, 0.0001);
		float h0 = hash11(seed * 1.7 + 0.3);
		float h1 = hash11(seed * 2.9 + 1.1);
		float h2 = hash11(seed * 4.3 + 2.7);
		float h3 = hash11(seed * 6.1 + 3.9);
		float h4 = hash11(seed * 8.3 + 5.3);
		float big = smoothstep(0.02, 0.12, v_size.y * 0.5);

		float body = 0.2 + 0.14 * h0;
		float rough = mix(0.5, 1.5, h2);
		float spiky = step(0.72, h3) * (0.4 + 0.6 * big);
		float wash = step(0.88, h1);
		vec2 q = vec2(p.x, p.y * mix(0.75, 1.5, h1));
		float qr = length(q);
		float qu = atan(q.y, q.x) / 6.2831853 + 0.5;

		float wob = rough * (0.14 * (vnoise(qu * 5.0 + seed * 19.0, 5.0) * 2.0 - 1.0) + 0.06 * (vnoise(qu * 12.0 + seed * 7.0, 12.0) * 2.0 - 1.0) + 0.03 * (vnoise(qu * 30.0 + seed * 3.0, 30.0) * 2.0 - 1.0));
		float lobe = smoothstep(0.5, 0.95, vnoise(qu * 3.0 + seed * 13.0, 3.0)) * (0.25 + 0.5 * spiky) * (0.4 + violence);
		float spine = pow(smoothstep(0.62, 0.95, vnoise(qu * 17.0 + seed * 5.0, 17.0)), 3.0) * 0.55 * spiky * violence;
		float edge = body * (1.0 + wob + lobe + spine);
		float d = qr - edge;
		float blob = 1.0 - smoothstep(-0.012, mix(0.012, 0.07, wash), d);

		float tail_k = clamp((aspect - 1.0) * 0.55 + h4 * h4 * 0.8 * violence, 0.0, 1.0);
		float tx = p.x - body * 0.5;
		float reach = (0.12 + 0.5 * tail_k) * (0.7 + 0.5 * h0);
		float t01 = clamp(tx / reach, 0.0, 1.0);
		float tw = body * 0.5 * pow(1.0 - t01, 1.3) * (0.45 + 0.55 * vnoise(p.x * 7.0 + seed * 5.0, 64.0));
		float tail = (1.0 - smoothstep(tw * 0.6, tw + 0.004, abs(p.y))) * step(0.0, tx) * step(tx, reach) * step(0.18, tail_k);

		float sat = 0.0;
		float count = floor(clamp(h0 * 2.0 + h4 * 3.0 + big * 4.0 * violence, 0.0, 6.0));
		for (int i = 0; i < 6; i++) {
			float fi = float(i);
			float s1 = hash11(seed * 17.0 + fi * 3.1);
			float s2 = hash11(seed * 5.0 + fi * 7.7);
			float s3 = hash11(seed * 9.0 + fi * 1.3);
			float cx = body * 1.2 + s2 * 0.5;
			float cy = (s1 - 0.5) * (0.12 + 0.45 * cx) * 1.8;
			float sz = (0.012 + 0.04 * s3 * s3) * (1.2 - 0.6 * cx);
			sat = max(sat, step(fi, count - 0.5) * (1.0 - smoothstep(sz * 0.6, sz, length(p - vec2(cx, cy)))));
		}

		mask = max(max(blob, tail * 0.95), sat);
		mask *= 1.0 - smoothstep(0.9, 1.0, max(abs(p.x), abs(p.y)));
		thick = clamp(-d / (edge * 0.7), 0.0, 1.0);
		thick = max(thick, tail * 0.35);
		rim = smoothstep(0.0, 0.1, -d);
		thin = mix(0.75, 0.5, wash);
		tone = vec3(mix(0.82, 1.18, h3));
	} else if (kind < 1.5) {
		float wob = 0.11 * (vnoise(u * 4.0 + seed * 9.0, 4.0) * 2.0 - 1.0) + 0.05 * (vnoise(u * 9.0 + seed * 5.0, 9.0) * 2.0 - 1.0) + 0.02 * (vnoise(u * 21.0 + seed * 3.0, 21.0) * 2.0 - 1.0);
		float finger = pow(smoothstep(0.5, 0.95, vnoise(u * 3.0 + seed * 13.0, 3.0)), 2.0) * 0.3 + pow(smoothstep(0.68, 1.0, vnoise(u * 7.0 + seed * 17.0, 7.0)), 2.0) * 0.16 + pow(smoothstep(0.8, 1.0, vnoise(u * 13.0 + seed * 23.0, 13.0)), 2.0) * 0.1;
		float edge = 0.6 + wob + finger;
		float d = r - edge;
		edge_dist = -d;
		mask = 1.0 - smoothstep(-0.012, 0.016, d);
		for (int i = 0; i < 5; i++) {
			float fi = float(i);
			float ang = hash11(seed * 3.0 + fi * 5.3) * 6.2831853;
			float dist = edge + 0.04 + 0.1 * hash11(seed * 7.0 + fi * 2.1);
			float sz = 0.012 + 0.03 * hash11(seed * 11.0 + fi * 4.7);
			float dot_mask = 1.0 - smoothstep(sz * 0.55, sz, length(p - vec2(cos(ang), sin(ang)) * dist));
			mask = max(mask, dot_mask * step(0.4, hash11(seed * 13.0 + fi * 9.1)));
		}

		thick = smoothstep(0.0, 0.2, -d);
		thin = 1.0;
	} else {
		float h = hash11(seed * 3.3 + 0.7);
		float front = v_data.w * (1.0 - exp(-age * 0.45));
		float along = UV.y;
		float smear = step(0.86, h);
		float wob = (vnoise(along * 9.0 + seed * 30.0, 64.0) - 0.5) * 0.7 + (vnoise(along * 31.0 + seed * 7.0, 64.0) - 0.5) * 0.2;
		float px = (p.x - wob) * v_size.x * 0.5;
		float swell = 0.75 + 0.5 * vnoise(along * 14.0 + seed * 3.0, 64.0);
		float width = mix(0.55, 1.9, h) * mix(1.0, 3.2, smear);
		float hw = mix(0.0038, 0.0022, clamp(along / max(front, 0.01), 0.0, 1.0)) * swell * width;
		float line = 1.0 - smoothstep(hw * 0.55, hw, abs(px));
		line *= smoothstep(0.0, 0.02, along) * (1.0 - smoothstep(front - 0.012, front, along));
		float bead = 1.0 - smoothstep(hw * 1.4, hw * 2.4, length(vec2(px, (along - front) * v_size.y)));
		mask = max(line, bead * step(0.02, front) * (1.0 - 0.7 * smear));
		thick = 0.7;
		thin = mix(1.0, 0.55, smear);
	}

	vec3 col = mix(fresh, dried, dry);

	if (kind > 0.5 && kind < 1.5) {
		float clot = noise2(p * 2.2 + seed * 7.0) * 0.65 + noise2(p * 6.0 + seed * 3.0) * 0.35;
		float dry_here = clamp(dry * mix(1.4, 0.55, thick), 0.0, 0.9);
		col = mix(fresh, dried, dry_here);
		col *= mix(0.8, 1.08, clot) * mix(1.0, 0.92, thick);
		col = mix(col * 1.35, col, thick);
		float meniscus = smoothstep(0.05, 0.0, abs(edge_dist - 0.015));
		col += vec3(0.07, 0.01, 0.012) * meniscus * (1.0 - dry);
		float far_side = smoothstep(-0.9, 0.5, -p.y);
		float sheen = smoothstep(0.35, 0.9, noise2(p * vec2(1.6, 3.5) + seed * 5.0)) * smoothstep(0.1, 0.5, thick) * far_side * (1.0 - dry);
		ALBEDO = col * v_col.rgb;
		ALPHA = mask * v_col.a * mix(0.6, 1.0, thick);
		ROUGHNESS = mix(0.45, 0.9, dry);
		SPECULAR = mix(0.18, 0.05, dry);
		float reflection = (1.0 - smoothstep(0.0, 0.8, UV.y)) * (0.55 + 0.45 * noise2(p * vec2(2.0, 1.2) + seed * 3.0)) * smoothstep(0.05, 0.4, thick) * (1.0 - dry);
		float glint = smoothstep(0.82, 0.98, noise2(p * vec2(3.2, 8.0) + seed * 11.0)) * smoothstep(0.1, 0.6, thick) * (1.0 - dry);
		EMISSION = ALBEDO * 0.38 + vec3(0.14, 0.02, 0.03) * sheen + vec3(0.1, 0.014, 0.022) * reflection + vec3(0.3, 0.09, 0.09) * glint + glow * dry * mask;
	} else {
		col = mix(col * film, col * 0.95, thick) * mix(0.88, 1.0, rim);
		ALBEDO = col * v_col.rgb * tone;
		ALPHA = mask * v_col.a * mix(thin, 1.0, thick);
		ROUGHNESS = mix(0.45, 0.9, dry);
		SPECULAR = mix(0.18, 0.05, dry) * (kind < 0.5 ? smoothstep(0.2, 0.7, dot(NORMAL, VIEW)) : 1.0);
		EMISSION = ALBEDO * 0.38 + glow * dry * mask;
	}
}
