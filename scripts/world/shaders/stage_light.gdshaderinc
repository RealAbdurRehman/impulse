uniform float lamp_spacing = 28.0;
uniform float lamp_z = 1.0;
uniform float wall_z = -6.0;
uniform float floor_radius = 16.0;
uniform float wall_radius = 11.0;
uniform float wall_rise = 10.0;
uniform float floor_min = 0.45;
uniform float wall_min = 0.3;

float lamp_offset(float x) {
	return x - floor(x / lamp_spacing + 0.5) * lamp_spacing;
}

float floor_pool(vec2 p) {
	float d = length(vec2(lamp_offset(p.x), p.y - lamp_z)) / floor_radius;
	float soft = 1.0 - smoothstep(0.0, 1.0, d);
	return mix(floor_min, 1.0, soft * soft);
}

float wall_pool(vec2 p) {
	float side = 1.0 - smoothstep(0.0, 1.0, abs(lamp_offset(p.x)) / wall_radius);
	return mix(wall_min, 1.0, side * side) * mix(0.55, 1.0, smoothstep(0.0, wall_rise, p.y));
}
