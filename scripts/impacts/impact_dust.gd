class_name ImpactDust
extends Node3D

const SHADER := preload("res://scripts/impacts/shaders/impact_dust.gdshader")

@export var capacity := 260

class Puff:
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var from := 0.0
	var to := 0.0
	var width := 0.4
	var heading := Vector2.RIGHT
	var life := 0.0
	var age := 0.0
	var density := 0.0
	var rise := 0.0
	var grain := 0.0
	var salt := Vector2.ZERO
	var tint := Color.WHITE
	var live := false

static var _noise: Texture2D

var _puffs: Array[Puff] = []
var _next := 0
var _multi: MultiMesh


func _ready() -> void:
	for i in capacity:
		_puffs.append(Puff.new())

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE

	_multi = MultiMesh.new()
	_multi.transform_format = MultiMesh.TRANSFORM_3D
	_multi.use_colors = true
	_multi.use_custom_data = true
	_multi.mesh = quad
	_multi.instance_count = capacity
	_multi.visible_instance_count = 0

	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.render_priority = 2
	material.set_shader_parameter("noise_tex", noise_texture())

	var holder := MultiMeshInstance3D.new()
	holder.multimesh = _multi
	holder.material_override = material
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.custom_aabb = AABB(Vector3.ONE * -5000.0, Vector3.ONE * 10000.0)
	add_child(holder)
	set_process(false)


func warm(on: bool) -> void:
	_multi.visible_instance_count = 1 if on else 0


func puff(pos: Vector3, vel: Vector3, style: SurfaceStyle, size: float) -> void:
	var p := _puffs[_next]
	_next = (_next + 1) % capacity
	p.pos = pos
	p.vel = vel * 0.12
	p.heading = Vector2(vel.x, vel.y).normalized() if absf(vel.x) + absf(vel.y) > 0.01 else Vector2.RIGHT
	p.from = style.dust_length.x * size
	p.to = style.dust_length.y * size * randf_range(0.55, 1.2)
	p.width = style.dust_width * randf_range(0.8, 1.2)
	p.life = randf_range(style.dust_life.x, style.dust_life.y)
	p.age = 0.0
	p.density = style.dust_density * randf_range(0.7, 1.0)
	p.rise = style.dust_rise
	p.grain = style.dust_grain
	p.salt = Vector2(randf(), randf()) * 4.0
	p.tint = style.dust_color.srgb_to_linear()
	p.live = true
	set_process(true)


func _process(delta: float) -> void:
	var out := 0
	for p in _puffs:
		if not p.live:
			continue

		p.age += delta
		if p.age >= p.life:
			p.live = false
			continue

		p.vel *= exp(-3.2 * delta)
		p.vel.y += p.rise * delta
		p.pos += p.vel * delta

		var k := p.age / p.life
		var length := lerpf(p.from, p.to, 1.0 - pow(1.0 - k, 2.2))
		var x := Vector3(p.heading.x, p.heading.y, 0.0) * length
		var y := Vector3(-p.heading.y, p.heading.x, 0.0) * length * p.width
		_multi.set_instance_transform(out, Transform3D(Basis(x, y, Vector3.BACK), p.pos + x * 0.5))
		_multi.set_instance_color(out, Color(p.tint.r, p.tint.g, p.tint.b, p.density))
		_multi.set_instance_custom_data(out, Color(k, p.salt.x, p.salt.y, p.grain))
		out += 1

	_multi.visible_instance_count = out
	if out == 0:
		set_process(false)


static func noise_texture() -> Texture2D:
	if _noise != null:
		return _noise

	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = 11
	n.frequency = 0.007
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 4
	n.fractal_gain = 0.45

	var img := n.get_seamless_image(512, 512, false, false, 0.2, true)
	img.generate_mipmaps()
	_noise = ImageTexture.create_from_image(img)
	return _noise
