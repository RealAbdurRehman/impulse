shader_type canvas_item;

uniform float vignette = 0.0;
uniform float scope = 0.0;
uniform vec2 scope_dir = vec2(1.0, 0.0);
uniform float fade = 0.0;
uniform float streaking = 0.0;
uniform vec4 hits[4];
uniform vec4 hit_style[4];

const vec3 BLOOD_DARK = vec3(0.26, 0.01, 0.015);
const vec3 BLOOD_WET = vec3(0.6, 0.045, 0.04);


float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}


float hash1(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}


float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}


float fbm(vec2 p) {
	return value_noise(p) * 0.55 + value_noise(p * 2.1 + 7.3) * 0.3 + value_noise(p * 4.3 + 3.1) * 0.15;
}


float smear(vec2 pos, vec2 entry, vec2 dir, float reach, float width, float seed) {
	vec2 rel = pos - entry;
	float along = dot(rel, dir);
	float t = along / reach;
	if (t < -0.2 || t > 1.5) {
		return 0.0;
	}

	float across = dot(rel, vec2(-dir.y, dir.x));
	float tip = 1.0 + (fbm(vec2(along * 9.0, across * 2.5) + seed * 17.0) - 0.5) * 0.8;
	float run = clamp(1.0 - t / tip, 0.0, 1.0);

	float w = width * (0.35 + 0.65 * pow(run, 0.5)) * (0.6 + 0.8 * fbm(vec2(along * 5.0, seed * 5.0)));
	float drift = (fbm(vec2(along * 3.0, seed * 9.0)) - 0.5) * width * 1.1;
	float body = 1.0 - smoothstep(0.0, w, abs(across - drift));

	float fibre = value_noise(vec2(along * 4.0, across * 60.0 + seed * 31.0));
	float grit = value_noise(vec2(along * 26.0, across * 26.0 + seed * 7.0));
	float density = body * (0.5 + 0.7 * fibre) * (0.75 + 0.5 * grit) * pow(run, 0.7);

	return density * smoothstep(-0.2, 0.05, t);
}


float speckle(vec2 pos, vec2 entry, vec2 dir, float reach, float seed) {
	vec2 side = vec2(-dir.y, dir.x);
	float total = 0.0;

	for (int j = 0; j < 6; j++) {
		float fj = float(j);
		float a = hash1(seed * 7.0 + fj * 1.3);
		float b = hash1(seed * 11.0 + fj * 2.9);
		float c = hash1(seed * 19.0 + fj * 4.1);

		vec2 at = entry + dir * (0.25 + a * 0.95) * reach + side * (b - 0.5) * reach * 0.55;
		vec2 d = pos - at;
		d = vec2(dot(d, dir) * 0.45, dot(d, side));

		float r = mix(0.0016, 0.0055, c * c);
		total += (1.0 - smoothstep(r * 0.3, r, length(d))) * mix(0.5, 1.0, c);
	}

	return clamp(total, 0.0, 1.0);
}


vec4 blood_hits(vec2 pos, float aspect) {
	float cover = 0.0;
	float heat = 0.0;

	for (int i = 0; i < 4; i++) {
		float s = hit_style[i].z;
		if (s <= 0.0) {
			continue;
		}

		float seed = hit_style[i].x;
		float strike = hit_style[i].y;
		float power = smoothstep(0.0, 1.0, s);
		vec2 entry = hits[i].xy * vec2(aspect, 1.0);
		vec2 dir = hits[i].zw;

		float reach = mix(0.27, 0.42, hash1(seed * 5.7)) * (0.55 + 0.45 * power) * (1.0 + 0.3 * strike);
		if (distance(pos, entry) > reach * 1.7 + 0.12) {
			continue;
		}

		float turn = (hash1(seed * 3.1) - 0.5) * 0.3;
		vec2 main_dir = vec2(dir.x * cos(turn) - dir.y * sin(turn), dir.x * sin(turn) + dir.y * cos(turn));
		vec2 main_in = entry - main_dir * 0.05;
		float width = mix(0.03, 0.05, hash1(seed * 8.3));

		float density = smear(pos, main_in, main_dir, reach, width, seed);

		if (hash1(seed * 13.9) > 0.4) {
			float turn2 = (hash1(seed * 17.3) - 0.5) * 0.6;
			vec2 dir2 = vec2(dir.x * cos(turn2) - dir.y * sin(turn2), dir.x * sin(turn2) + dir.y * cos(turn2));
			float lateral = (hash1(seed * 21.7) > 0.5 ? 1.0 : -1.0) * mix(0.05, 0.1, hash1(seed * 23.9));
			vec2 in2 = entry + vec2(-dir.y, dir.x) * lateral - dir2 * 0.05;

			density = max(density, smear(pos, in2, dir2, reach * 0.55, width * 0.55, seed + 4.0) * 0.85);
		}

		float drops = speckle(pos, main_in, main_dir, reach, seed + 2.0);
		float cut = smoothstep(0.12, 0.45, density) * power;
		cover = 1.0 - (1.0 - cover) * (1.0 - cut) * (1.0 - drops * power * 0.75);
		heat = max(heat, max(density * density * 1.6, drops * 0.5));

		float near = length(pos - entry);
		cover = 1.0 - (1.0 - cover) * (1.0 - exp(-near * near * 70.0) * power * 0.14);
	}

	return vec4(mix(BLOOD_DARK * 1.25, BLOOD_WET, clamp(heat, 0.0, 1.0)), clamp(cover, 0.0, 0.9));
}


void fragment() {
	vec2 centre = SCREEN_UV - 0.5;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float rim = smoothstep(0.3, 1.0, length(vec2(centre.x * aspect, centre.y)));

	float dark = vignette * rim;
	if (scope > 0.001) {
		float behind = 1.0 - smoothstep(-0.55, 0.15, dot(vec2(centre.x, -centre.y) * 2.0, scope_dir));
		dark += scope * behind * rim;
	}

	dark = clamp(dark, 0.0, 1.0);

	vec4 splash = vec4(0.0);
	if (streaking > 0.0) {
		splash = blood_hits(vec2(SCREEN_UV.x * aspect, SCREEN_UV.y), aspect);
	}

	float covered = splash.a + dark * (1.0 - splash.a);
	vec3 paint = splash.rgb * splash.a;

	float alpha = fade + covered * (1.0 - fade);
	paint *= 1.0 - fade;

	COLOR = vec4(paint / max(alpha, 0.0001), alpha);
}
