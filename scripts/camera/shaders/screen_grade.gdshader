shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, repeat_disable, filter_linear;

uniform float aberration = 0.0;
uniform float lens = 0.0;
uniform float tone = 0.0;
uniform float desaturate = 0.0;
uniform float focus = 0.0;
uniform float haze = 0.0;
uniform float blood = 0.0;
uniform vec2 scope_dir = vec2(1.0, 0.0);
uniform vec2 scope_anchor = vec2(0.5, 0.5);

const vec3 LUMA = vec3(0.299, 0.587, 0.114);


void fragment() {
	vec2 centre = SCREEN_UV - 0.5;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float radius = length(vec2(centre.x * aspect, centre.y));

	float zone = 0.0;
	float fringe = 0.0;
	if (focus + haze > 0.01) {
		float behind = 1.0 - smoothstep(-0.55, 0.15, dot(vec2(centre.x, -centre.y) * 2.0, scope_dir));
		float clear = smoothstep(0.07, 0.24, length((SCREEN_UV - scope_anchor) * vec2(aspect, 1.0)));
		zone = (focus * behind + haze) * clear * smoothstep(0.3, 0.95, radius);
		fringe = focus * behind * clear;
	}

	vec3 col = textureLod(screen, SCREEN_UV, 0.0).rgb;
	if (zone > 0.003) {
		vec2 px = vec2(1.0 / aspect, 1.0) * zone * 0.0052;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785398;
			col += textureLod(screen, SCREEN_UV + vec2(cos(a), sin(a)) * px, 0.0).rgb;
		}

		col /= 9.0;
	}

	float split = aberration + 0.0035 * fringe;
	float rim_lens = lens * smoothstep(0.2, 0.9, radius);
	if (split + rim_lens > 0.0002) {
		vec2 shift = centre * (split * (0.35 + radius) + rim_lens);
		float keep = zone > 0.003 ? 0.5 : 0.0;
		col.r = mix(textureLod(screen, SCREEN_UV + shift, 0.0).r, col.r, keep);
		col.b = mix(textureLod(screen, SCREEN_UV - shift, 0.0).b, col.b, keep);
	}

	float lum = dot(col, LUMA);
	col *= mix(vec3(1.0), mix(vec3(0.94, 1.0, 1.07), vec3(1.07, 1.0, 0.93), smoothstep(0.15, 0.75, lum)), tone);

	col = mix(col, vec3(dot(col, LUMA)), desaturate);

	float rim = smoothstep(0.3, 1.0, radius);
	col = mix(col, vec3(dot(col, LUMA)) * vec3(1.45, 0.45, 0.4), clamp(blood * rim, 0.0, 1.0));

	COLOR = vec4(col, 1.0);
}
