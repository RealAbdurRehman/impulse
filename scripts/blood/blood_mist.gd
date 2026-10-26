class_name BloodMist
extends Node3D

const SHADER := preload("res://scripts/blood/shaders/blood_mist.gdshader")

@export var capacity := 80


class Puff:
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var drag := 0.0
	var from := 0.0
	var to := 0.0
	var life := 0.0
	var age := 0.0
	var density := 0.0
	var salt := 0.0
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
	_multi.use_custom_data = true
	_multi.mesh = quad
	_multi.instance_count = capacity
	_multi.visible_instance_count = 0

	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.render_priority = 3
	material.set_shader_parameter("noise_tex", _noise_texture())

	var holder := MultiMeshInstance3D.new()
	holder.multimesh = _multi
	holder.material_override = material
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.custom_aabb = AABB(Vector3.ONE * -5000.0, Vector3.ONE * 10000.0)
	add_child(holder)
	set_process(false)


func warm(on: bool) -> void:
	_multi.visible_instance_count = 1 if on else 0


func puff(
	pos: Vector3,
	vel: Vector3,
	from: float,
	to: float,
	life: float,
	density: float,
	drag := 3.0,
) -> void:
	var p := _puffs[_next]
	_next = (_next + 1) % capacity
	p.pos = pos
	p.vel = vel
	p.drag = drag
	p.from = from
	p.to = to
	p.life = life
	p.age = 0.0
	p.density = density
	p.salt = randf() * 4.0
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

		p.vel *= exp(-p.drag * delta)
		p.vel.y += 0.35 * delta
		p.pos += p.vel * delta

		var k := p.age / p.life
		var size := lerpf(p.from, p.to, 1.0 - pow(1.0 - k, 2.2))
		_multi.set_instance_transform(out, Transform3D(Basis.from_scale(Vector3.ONE * size), p.pos))
		_multi.set_instance_custom_data(out, Color(k, p.salt, p.density, 0.0))
		out += 1

	_multi.visible_instance_count = out
	if out == 0:
		set_process(false)


static func _noise_texture() -> Texture2D:
	if _noise != null:
		return _noise

	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = 23
	n.frequency = 0.02
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 4
	n.fractal_gain = 0.5

	var img := n.get_seamless_image(256, 256, false, false, 0.2, true)
	img.generate_mipmaps()
	_noise = ImageTexture.create_from_image(img)
	return _noise
