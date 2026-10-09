class_name WeaponFx
extends Node3D


class Casing extends RigidBody3D:
	var age := 0.0
	var life := 8.0

	var pivot := Node3D.new()


	func _init() -> void:
		add_child(pivot)
		retire()


	func launch(at: Transform3D, linear: Vector3, angular: Vector3, lifetime: float) -> void:
		age = 0.0
		life = lifetime
		pivot.scale = Vector3.ONE

		freeze = false
		sleeping = false
		global_transform = at
		linear_velocity = linear
		angular_velocity = angular
		visible = true

		reset_physics_interpolation()
		set_physics_process(true)


	func retire() -> void:
		freeze = true
		visible = false
		set_physics_process(false)


	func _physics_process(delta: float) -> void:
		age += delta

		var left := life - age
		if left <= 0.0:
			retire()
		elif left < 0.5:
			pivot.scale = Vector3.ONE * (left / 0.5)


class Tracer:
	var mesh: MeshInstance3D
	var material: ShaderMaterial
	var from := Vector3.ZERO
	var dir := Vector3.RIGHT
	var basis := Basis.IDENTITY
	var dist := 0.0
	var head := 0.0
	var length := 1.0
	var width := 0.02
	var speed := 100.0
	var active := false


class Wisp:
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var age := 0.0
	var life := 1.0
	var along := 0.0
	var quad := false
	var noise_seed := 0.0
	var phase := 0.0
	var strength := 1.0


class Sprite:
	var mesh: MeshInstance3D
	var material: ShaderMaterial
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var accel := Vector3.ZERO
	var drag := 1.0
	var basis := Basis.IDENTITY
	var size_from := Vector2.ONE
	var size_to := Vector2.ONE
	var age := 0.0
	var life := 1.0
	var active := false


const SMOKE_LAYERS := [
	{
		"offset": 0.1,
		"spread": 0.1,
		"from": Vector2(0.4, 0.16),
		"to": Vector2(1.3, 0.34),
		"life": 0.6,
		"speed": 1.8,
		"drag": 3.4,
		"rise": 0.08,
		"density": 0.5,
		"noise": Vector2(1.3, 0.6),
		"flow": Vector2(0.35, 0.04),
	},
	{
		"offset": 0.22,
		"spread": 0.14,
		"from": Vector2(0.7, 0.22),
		"to": Vector2(1.9, 0.5),
		"life": 0.8,
		"speed": 1.2,
		"drag": 2.4,
		"rise": 0.12,
		"density": 0.47,
		"noise": Vector2(1.2, 0.55),
		"flow": Vector2(0.3, 0.05),
	},
	{
		"offset": 0.4,
		"spread": 0.18,
		"from": Vector2(1.0, 0.3),
		"to": Vector2(2.6, 0.65),
		"life": 1.0,
		"speed": 0.8,
		"drag": 1.6,
		"rise": 0.18,
		"density": 0.38,
		"noise": Vector2(1.0, 0.45),
		"flow": Vector2(0.2, 0.06),
	},
	{
		"offset": 0.55,
		"spread": 0.22,
		"from": Vector2(1.1, 0.34),
		"to": Vector2(2.9, 0.75),
		"life": 1.1,
		"speed": 0.6,
		"drag": 1.4,
		"rise": 0.2,
		"density": 0.3,
		"noise": Vector2(0.95, 0.42),
		"flow": Vector2(0.15, 0.06),
	},
	{
		"offset": 0.7,
		"spread": 0.28,
		"from": Vector2(1.3, 0.4),
		"to": Vector2(3.2, 0.85),
		"life": 1.2,
		"speed": 0.45,
		"drag": 1.3,
		"rise": 0.22,
		"density": 0.25,
		"noise": Vector2(0.9, 0.4),
		"flow": Vector2(0.12, 0.05),
	},
	{
		"offset": 0.3,
		"spread": 0.35,
		"from": Vector2(0.5, 0.2),
		"to": Vector2(1.2, 0.5),
		"life": 0.7,
		"speed": 0.9,
		"drag": 2.0,
		"rise": 0.25,
		"density": 0.28,
		"noise": Vector2(1.6, 0.8),
		"flow": Vector2(0.25, 0.1),
	},
]

const FLASH_SPREAD := 1.7
const IDLE_LIGHT := 0.0001
const HEAT_FLOOR := 0.015
const HEAT_DECAY := 6.0
const WISP_STEP := 0.035
const WISP_SMOOTH := 4
const WISP_QUAD_TIME := 0.14
const WISP_QUAD_GAP := 0.06
const WISP_TRAVEL_GAP := 0.04
const WISP_TAPER := 0.012
const WISP_REACH := 0.04
const WISP_FOLLOW := 10.0
const WISP_ALPHA := 2.6
const WISP_STRENGTH := 0.4
const WISP_FADE := Vector2(0.1, 0.65)
const WISP_V := 0.0049
const WISP_AFTER := 0.3
const WISP_DELAY := 0.05
const WISP_FROM := Vector2(0.06, 0.03)
const QUAD: Array[Vector2] = [
	Vector2(0.0, 0.0),
	Vector2(1.0, 0.0),
	Vector2(1.0, 1.0),
	Vector2(0.0, 0.0),
	Vector2(1.0, 1.0),
	Vector2(0.0, 1.0),
]

@export var casing_node: StringName = &"BulletCasing"

@export_group("Pools")
@export var sprite_pool := 160
@export var max_casings := 40
@export var tracer_pool := 12
@export var max_strands := 4

@export_group("Quality")
@export var noise_size := 1024

@export_flags_3d_physics var casing_layer := 4
@export_flags_3d_physics var casing_mask := 1

var weapon: Weapon

var _noise: Texture2D
var _flash_shader: Shader
var _smoke_shader: Shader
var _tracer_shader: Shader
var _stream_shader: Shader
var _stream_material: ShaderMaterial
var _stream: MeshInstance3D
var _stream_mesh: ImmediateMesh

var _anchor: Node3D
var _shift := Vector3.ZERO
var _flash_root: Node3D
var _flash: MeshInstance3D
var _light: OmniLight3D
var _flash_left := 0.0
var _flash_total := 0.05

var _sprites: Array[Sprite] = []
var _sprite_next := 0
var _silent := false
var _heat := 0.0
var _since_shot := 0.0
var _strands: Array[Array] = []
var _wisp_open := false
var _wisp_seed := 0.0
var _wisp_phase := 0.0
var _wisp_rel := Vector3.ZERO
var _wisp_count := 0.0
var _wisp_travel := 0.0
var _wisp_last := Vector3.ZERO
var _wisp_seen := Vector3.ZERO
var _wisp_quad := Vector3.ZERO
var _wisp_since := 0.0
var _wisp_delay := 0.0
var _wisp_timer := 0.0
var _wisp_clock := 0.0

var _casings: Array[Casing] = []
var _casing_next := 0
var _casing_gun: Node3D

var _tracers: Array[Tracer] = []
var _tracer_next := 0


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	set_process(false)

	weapon = get_parent() as Weapon

	var dir := (get_script() as Script).resource_path.get_base_dir()
	_flash_shader = load(dir.path_join("muzzle_flash.gdshader")) as Shader
	_smoke_shader = load(dir.path_join("smoke.gdshader")) as Shader
	_tracer_shader = load(dir.path_join("tracer.gdshader")) as Shader
	_stream_shader = load(dir.path_join("smoke_stream.gdshader")) as Shader
	_noise = _noise_texture()

	_build_sprites()
	_build_stream()
	_build_tracers()

	weapon.fired.connect(_on_fired)
	weapon.bullet_traced.connect(_on_bullet_traced)
	weapon.animator.ejected.connect(_eject)

	_prewarm.call_deferred()


func _process(delta: float) -> void:
	var busy := _update_flash(delta)
	busy = _update_tracers(delta) or busy
	busy = _update_wisps(delta) or busy
	busy = _update_sprites(delta) or busy

	if not busy:
		set_process(false)


func _on_fired(muzzle: Transform3D) -> void:
	if _flash_root == null:
		_build_flash()

	_shift = _current_shift()
	muzzle.origin += _shift

	_start_flash()
	_puff(muzzle)

	if not _wisp_open:
		_wisp_rel = muzzle.origin - weapon.player.get_global_transform_interpolated().origin

	_heat = minf(_heat + weapon.stats.barrel_heat_per_shot, 1.0)
	_since_shot = 0.0
	set_process(true)


func _current_shift() -> Vector3:
	var shift := _anchor.get_global_transform_interpolated().origin - _anchor \
			.global_transform \
			.origin
	return Vector3.ZERO if shift.length() > 0.5 else shift


func _on_bullet_traced(from: Vector3, to: Vector3, _hit: Dictionary) -> void:
	var s := weapon.stats
	var dist := from.distance_to(to)
	if dist < 0.5 or randf() > s.tracer_chance:
		return

	from += _shift
	to += _shift

	var t := _tracers[_tracer_next]
	_tracer_next = (_tracer_next + 1) % _tracers.size()

	var dir := (to - from) / dist

	t.from = from
	t.dir = dir
	t.basis = _facing(dir, from)
	t.dist = dist
	t.head = 0.0
	t.length = s.tracer_length
	t.width = s.tracer_width
	t.speed = s.tracer_speed
	t.mesh.visible = false
	t.active = true

	t.material.set_shader_parameter("core_color", _rgb(s.tracer_color))
	t.material.set_shader_parameter("glow_color", _rgb(s.tracer_glow_color))
	t.material.set_shader_parameter("seed", Vector2(randf(), randf()))
	t.material.set_shader_parameter("length_m", s.tracer_length)
	t.material.set_shader_parameter("level", 0.0 if _silent else 1.0)

	set_process(true)


func _facing(dir: Vector3, at: Vector3) -> Basis:
	var view := get_viewport().get_camera_3d().global_position - at
	var z := (view - dir * dir.dot(view)).normalized()

	return Basis(dir, z.cross(dir), z)


func _build_flash() -> void:
	_anchor = weapon.holder.muzzle

	_flash_root = Node3D.new()
	_flash_root.visible = false
	_anchor.add_child(_flash_root)
	_flash_root.scale = Vector3.ONE / _anchor.global_transform.basis.get_scale()

	_flash = MeshInstance3D.new()
	_flash.mesh = QuadMesh.new()
	_flash.material_override = _shader_material(_flash_shader)
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash_root.add_child(_flash)

	_light = OmniLight3D.new()
	_light.top_level = true
	_light.visible = false
	_light.shadow_enabled = false
	_light.light_specular = 0.2
	_light.omni_attenuation = 2.0
	add_child(_light)


func _rgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


func _shader_material(shader: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("noise_tex", _noise)

	return m


func _start_flash() -> void:
	var s := weapon.stats
	_flash_total = maxf(s.flash_duration, 0.01)
	_flash_left = _flash_total

	var big := 1.3 if randf() < 0.15 else 1.0
	var length := s.flash_length * big * randf_range(0.8, 1.2)
	var width := s.flash_width * big * randf_range(0.8, 1.2)

	_flash.position = Vector3(0.012 + length * 0.5, 0.0, 0.0)
	_flash.scale = Vector3(length * FLASH_SPREAD, width * FLASH_SPREAD, 1.0)
	_flash.reset_physics_interpolation()

	var m := _flash.material_override as ShaderMaterial
	m.set_shader_parameter("rim_color", _rgb(s.flash_color))
	m.set_shader_parameter("seed", Vector2(randf(), randf()))
	m.set_shader_parameter("lobes", randf_range(0.08, 0.2))
	m.set_shader_parameter("taper", randf_range(0.15, 0.45))
	m.set_shader_parameter("shift", randf_range(-0.15, 0.15))
	m.set_shader_parameter("squareness", randf_range(2.0, 3.0))
	m.set_shader_parameter("glow", s.flash_glow)

	_light.light_color = s.flash_color.lerp(Color.WHITE, 0.45)
	_light.omni_range = s.light_range

	_apply_flash_level(1.0, 0.0)
	_place_light()

	_flash_root.visible = true
	_light.visible = true


func _update_flash(delta: float) -> bool:
	if _flash_left <= 0.0:
		return false

	_flash_left -= delta
	if _flash_left <= 0.0:
		_flash_root.visible = false
		_light.light_energy = IDLE_LIGHT
		return false

	var t := 1.0 - _flash_left / _flash_total
	_apply_flash_level(1.0 - smoothstep(0.88, 1.0, t), t)
	_place_light()

	return true


func _apply_flash_level(level: float, age: float) -> void:
	var m := _flash.material_override as ShaderMaterial
	var gain := 0.0 if _silent else 1.0
	m.set_shader_parameter("level", level * gain)
	m.set_shader_parameter("age", age)
	m.set_shader_parameter("fade", smoothstep(0.5, 1.0, age))
	_light.light_energy = IDLE_LIGHT + weapon.stats.light_energy * gain * (
		1.0 - smoothstep(0.3, 1.0, age)
	)


func _place_light() -> void:
	var xf := _anchor.get_global_transform_interpolated()
	_light.global_position = xf.origin + xf.basis.x.normalized() * 0.08 + Vector3(0.0, 0.0, 0.25)


func _update_tracers(delta: float) -> bool:
	var busy := false
	for t in _tracers:
		if not t.active:
			continue

		t.head += t.speed * delta

		var tip := minf(t.head, t.dist)
		var tail := clampf(t.head - t.length, 0.0, t.dist)
		if tail >= t.dist - 0.001:
			t.active = false
			t.mesh.visible = false
			continue

		var span := tip - tail
		t.mesh.global_transform = Transform3D(
			t.basis * Basis.from_scale(Vector3(span, t.width, 1.0)),
			t.from + t.dir * (tail + span * 0.5),
		)
		t.material.set_shader_parameter("scroll", t.head * 0.15)
		t.mesh.visible = true

		busy = true

	return busy


func _build_sprites() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE

	for i in sprite_pool:
		_sprites.append(_make_sprite(quad))


func _make_sprite(quad: Mesh) -> Sprite:
	var sp := Sprite.new()
	sp.material = _shader_material(_smoke_shader)
	sp.mesh = MeshInstance3D.new()
	sp.mesh.mesh = quad
	sp.mesh.material_override = sp.material
	sp.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sp.mesh.visible = false

	add_child(sp.mesh)

	return sp


func _take_sprite() -> Sprite:
	var sp := _sprites[_sprite_next]
	_sprite_next = (_sprite_next + 1) % _sprites.size()

	return sp


func _spawn_sprite(
	sp: Sprite,
	pos: Vector3,
	dir: Vector3,
	size_from: Vector2,
	size_to: Vector2,
	life: float,
	vel: Vector3,
	drag: float,
	accel: Vector3,
	density: float,
	noise_scale: Vector2,
	flow: Vector2,
) -> void:
	pos.z += fmod(float(_sprite_next), 30.0) * 0.004

	sp.pos = pos
	sp.vel = vel
	sp.accel = accel
	sp.drag = drag
	sp.basis = _facing(dir, pos)
	sp.size_from = size_from
	sp.size_to = size_to
	sp.age = 0.0
	sp.life = life
	sp.active = true
	sp.mesh.visible = false

	sp.material.set_shader_parameter("tint", _rgb(weapon.stats.smoke_color))
	sp.material.set_shader_parameter("seed", Vector2(randf(), randf()) * 4.0)
	sp.material.set_shader_parameter("noise_scale", noise_scale)
	sp.material.set_shader_parameter("flow", flow)
	sp.material.set_shader_parameter("density", 0.0 if _silent else density)
	sp.material.set_shader_parameter("age", 0.0)

	set_process(true)


func _update_sprites(delta: float) -> bool:
	return _step_sprites(_sprites, delta)


func _step_sprites(list: Array[Sprite], delta: float) -> bool:
	var busy := false
	for sp in list:
		if not sp.active:
			continue

		sp.age += delta
		if sp.age >= sp.life:
			sp.active = false
			sp.mesh.visible = false

			continue

		sp.vel *= exp(-sp.drag * delta)
		sp.vel += sp.accel * delta
		sp.pos += sp.vel * delta

		var k := sp.age / sp.life
		var size := sp.size_from.lerp(sp.size_to, 1.0 - pow(1.0 - k, 2.5))
		sp.mesh.global_transform = Transform3D(
			sp.basis * Basis.from_scale(Vector3(size.x, size.y, 1.0)),
			sp.pos,
		)
		sp.material.set_shader_parameter("age", k)
		sp.mesh.visible = true
		busy = true

	return busy


func _puff(muzzle: Transform3D) -> void:
	var s := weapon.stats
	var dir := Vector3(muzzle.basis.x.x, muzzle.basis.x.y, 0.0).normalized()
	var o := muzzle.origin
	var k := s.smoke_size
	var life := s.smoke_lifetime
	var drift := s.smoke_speed
	var up := Vector3.UP

	for layer in SMOKE_LAYERS:
		var jitter: float = layer.spread
		_spawn_sprite(
			_take_sprite(),
			o + dir * layer.offset * k,
			dir.rotated(Vector3.BACK, randf_range(-jitter, jitter)),
			layer.from * k * randf_range(0.9, 1.1),
			layer.to * k * randf_range(0.9, 1.1),
			life * layer.life * randf_range(0.9, 1.1),
			dir * drift * layer.speed * randf_range(0.85, 1.15),
			layer.drag,
			up * layer.rise,
			s.smoke_opacity * layer.density,
			layer.noise,
			layer.flow,
		)


func _update_wisps(delta: float) -> bool:
	var s := weapon.stats
	_wisp_clock += delta
	_since_shot += delta

	var settled := _since_shot >= WISP_AFTER
	if settled:
		_heat *= exp(-delta * HEAT_DECAY / maxf(s.barrel_cool_time, 0.1))

	var hot := _heat >= HEAT_FLOOR and s.barrel_heat_per_shot > 0.0
	var emitting := hot and settled
	if emitting:
		_emit_wisps(delta)
	else:
		_wisp_open = false
		if settled and not hot:
			_heat = 0.0

	_step_strands(delta)
	_rebuild_stream()

	return hot or not _strands.is_empty()


func _emit_wisps(delta: float) -> void:
	var xf := _anchor.get_global_transform_interpolated()
	var body := weapon.player.get_global_transform_interpolated().origin

	if not _wisp_open:
		_wisp_open = true
		_wisp_delay = WISP_DELAY
		_wisp_timer = 0.0
		_wisp_since = WISP_QUAD_TIME
		_wisp_seed = randf()
		_wisp_phase = randf() * TAU
		_wisp_seen = body + _wisp_rel
		_strands.append([])
		while _strands.size() > max_strands:
			_strands.pop_front()

	_wisp_rel = _wisp_rel.lerp(xf.origin - body, 1.0 - exp(-WISP_FOLLOW * delta))

	var tip := body + _wisp_rel
	var speed := tip.distance_to(_wisp_seen) / maxf(delta, 0.0001)
	_wisp_seen = tip

	_wisp_delay -= delta
	if _wisp_delay > 0.0:
		_wisp_last = tip
		_wisp_quad = tip
		return

	_wisp_since += delta
	_wisp_timer -= delta
	if tip.distance_to(_wisp_last) >= WISP_TRAVEL_GAP:
		_wisp_timer = 0.0

	var strength := minf(sqrt(_heat) * 1.4, WISP_STRENGTH) / (1.0 + speed * 0.25)
	strength *= smoothstep(HEAT_FLOOR, HEAT_FLOOR * 3.0, _heat)
	if _silent:
		strength = 0.0

	var strand: Array = _strands.back()
	while _wisp_timer <= 0.0:
		_wisp_timer += WISP_STEP
		_emit_wisp(strand, tip, xf, strength)


func _emit_wisp(strand: Array, tip: Vector3, xf: Transform3D, strength: float) -> void:
	var s := weapon.stats
	var fwd := Vector3(xf.basis.x.x, xf.basis.x.y, 0.0).normalized()

	_wisp_travel += tip.distance_to(_wisp_last)
	_wisp_last = tip

	var w := Wisp.new()
	w.pos = tip
	w.vel = fwd * 0.03 + Vector3(0.0, s.barrel_smoke_rise * 0.5, 0.0)
	w.life = s.barrel_smoke_lifetime * randf_range(0.94, 1.06)
	w.along = _wisp_travel + _wisp_count * WISP_V
	w.noise_seed = _wisp_seed
	w.phase = _wisp_phase
	w.strength = strength
	w.quad = _wisp_since >= WISP_QUAD_TIME or tip.distance_to(_wisp_quad) >= WISP_QUAD_GAP
	strand.append(w)

	if w.quad:
		_wisp_since = 0.0
		_wisp_quad = tip

	_wisp_count += 1.0


func _step_strands(delta: float) -> void:
	var s := weapon.stats
	var rise := s.barrel_smoke_rise
	var gust := sin(_wisp_clock * 0.9) * 0.012

	for strand in _strands:
		for w: Wisp in strand:
			w.age += delta

			var k := w.age / w.life
			var sway := sin(w.age * 2.2 + w.phase) * 0.03 * (0.25 + k) + gust
			var lift := rise * (1.0 + k * 0.8)

			w.vel.x = lerpf(w.vel.x, sway, 1.0 - exp(-1.2 * delta))
			w.vel.y = lerpf(w.vel.y, lift, 1.0 - exp(-1.5 * delta))
			w.pos += w.vel * delta

		while not strand.is_empty() and (strand[0] as Wisp).age >= (strand[0] as Wisp).life:
			strand.pop_front()

	var i := 0
	while i < _strands.size():
		if _strands[i].is_empty() and not (_wisp_open and i == _strands.size() - 1):
			_strands.remove_at(i)
		else:
			i += 1


func _rebuild_stream() -> void:
	var s := weapon.stats
	_stream_mesh.clear_surfaces()

	var begun := false
	for index in _strands.size():
		var points: Array = (_strands[index] as Array).duplicate()
		if _wisp_open and index == _strands.size() - 1 and not points.is_empty():
			var head := Wisp.new()
			head.pos = _wisp_seen
			head.life = 1.0
			points.append(head)

		var count := points.size()
		if count < 2:
			continue

		var path: Array[Vector3] = []
		var arc: Array[float] = []
		for i in count:
			var reach := mini(WISP_SMOOTH, mini(i, count - 1 - i))
			var total := Vector3.ZERO
			for j in range(i - reach, i + reach + 1):
				total += (points[j] as Wisp).pos

			path.append(total / float(reach * 2 + 1))
			arc.append(0.0 if i == 0 else arc[i - 1] + path[i].distance_to(path[i - 1]))

		var quads: Array[int] = []
		for i in count:
			if (points[i] as Wisp).quad:
				quads.append(i)

		var tangent := Vector3.UP
		var lo := 0
		var hi := 0
		for q in quads.size():
			var i := quads[q]
			var w: Wisp = points[i]
			var k := clampf(w.age / w.life, 0.0, 1.0)
			var spread := 1.0 - (1.0 - k) * (1.0 - k)

			var gap := 0.0
			var neighbors := 0.0
			if q > 0:
				gap += arc[i] - arc[quads[q - 1]]
				neighbors += 1.0

			if q < quads.size() - 1:
				gap += arc[quads[q + 1]] - arc[i]
				neighbors += 1.0

			gap /= maxf(neighbors, 1.0)

			var length := maxf(lerpf(WISP_FROM.x, s.barrel_smoke_size * 1.6, spread), gap * 1.8)
			var width := lerpf(WISP_FROM.y, s.barrel_smoke_size * 1.2, spread)

			var reach := maxf(WISP_REACH, length * 0.5)
			while arc[i] - arc[lo] > reach:
				lo += 1

			hi = maxi(hi, i)
			while hi < count - 1 and arc[hi + 1] - arc[i] <= reach:
				hi += 1

			var span := path[hi] - path[lo]
			if span.length_squared() > 0.0000001:
				tangent = span.normalized()

			var taper := smoothstep(0.0, WISP_TAPER, arc[count - 1] - arc[i])
			var fade := taper * smoothstep(0.0, 0.05, k)
			fade *= 1.0 - smoothstep(WISP_FADE.x, WISP_FADE.y, k)
			var alpha := fade * w.strength * s.barrel_smoke_opacity * WISP_ALPHA
			alpha *= clampf(gap / length, 0.1, 1.0)

			var along := tangent * (length * 0.5)
			var across := Vector3(-tangent.y, tangent.x, 0.0) * (width * 0.5)

			if not begun:
				begun = true
				_stream_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _stream_material)

			_stream_mesh.surface_set_color(Color(k, w.noise_seed, width * 4.0, alpha))
			_stream_mesh.surface_set_uv2(Vector2(length, w.along))

			for corner: Vector2 in QUAD:
				_stream_mesh.surface_set_uv(corner)
				_stream_mesh.surface_add_vertex(
					path[i] + along * (corner.x * 2.0 - 1.0) + across * (corner.y * 2.0 - 1.0),
				)

	if begun:
		_stream_mesh.surface_end()


func _build_stream() -> void:
	_stream_material = _shader_material(_stream_shader)
	_stream_material.set_shader_parameter("tint", _rgb(weapon.stats.smoke_color))
	_stream_mesh = ImmediateMesh.new()

	_stream = MeshInstance3D.new()
	_stream.mesh = _stream_mesh
	_stream.top_level = true
	_stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stream.custom_aabb = AABB(Vector3(-50.0, -50.0, -5.0), Vector3(100.0, 100.0, 10.0))
	add_child(_stream)
	_stream.global_transform = Transform3D.IDENTITY


func _prewarm() -> void:
	while not weapon.holder.gun.is_inside_tree():
		await get_tree().process_frame

	_build_flash()
	_build_casings()
	_light.light_energy = IDLE_LIGHT
	_light.visible = true

	var cam := get_viewport().get_camera_3d()
	var spot := Transform3D(
		Basis.from_scale(Vector3.ONE * 0.001),
		cam.global_position - cam.global_basis.z,
	)

	var quad := QuadMesh.new()
	var warm: Array[Node3D] = []
	var materials: Array[Material] = [_flash.material_override]
	for sprite in _sprites:
		materials.append(sprite.material)

	for tracer in _tracers:
		materials.append(tracer.material)

	for material in materials:
		var piece := MeshInstance3D.new()
		piece.mesh = quad
		piece.material_override = material
		piece.top_level = true
		add_child(piece)
		piece.global_transform = spot
		warm.append(piece)

	var trail := ImmediateMesh.new()
	trail.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _stream_material)
	trail.surface_set_color(Color(0.0, 0.0, 0.0, 0.0))
	trail.surface_set_uv2(Vector2.ONE)
	for corner: Vector2 in QUAD:
		trail.surface_set_uv(corner)
		trail.surface_add_vertex(Vector3(corner.x, corner.y, 0.0))
	trail.surface_end()

	var trail_piece := MeshInstance3D.new()
	trail_piece.mesh = trail
	trail_piece.top_level = true
	add_child(trail_piece)
	trail_piece.global_transform = spot
	warm.append(trail_piece)

	var casing := _casings[0].pivot.get_child(0).duplicate() as Node3D
	casing.top_level = true
	add_child(casing)
	casing.global_transform = spot
	warm.append(casing)

	var cartridge := weapon.holder.gun.get_node(NodePath(weapon.animator.feed_part)).duplicate() as Node3D
	cartridge.visible = true
	cartridge.top_level = true
	add_child(cartridge)
	cartridge.global_transform = spot
	warm.append(cartridge)

	await get_tree().process_frame
	await get_tree().process_frame

	for piece in warm:
		piece.queue_free()

	_silent = true
	weapon.animator.slide_node()

	var muzzle := weapon.holder.muzzle_transform()
	var fwd := Vector3(muzzle.basis.x.x, muzzle.basis.x.y, 0.0).normalized()
	_on_fired(muzzle)
	_on_bullet_traced(muzzle.origin, muzzle.origin + fwd * 3.0, { })
	_eject()
	_casings[_casing_next - 1].pivot.scale = Vector3.ONE * 0.001

	for i in 40:
		await get_tree().process_frame

	for c in _casings:
		c.retire()

	for sp in _sprites:
		sp.active = false
		sp.mesh.visible = false

	for t in _tracers:
		t.active = false
		t.mesh.visible = false

	_strands.clear()
	_wisp_open = false
	_flash_left = 0.0
	_flash_root.visible = false
	_light.light_energy = IDLE_LIGHT
	_heat = 0.0
	_silent = false


func _build_casings() -> void:
	var gun := weapon.holder.gun
	_casing_gun = gun

	for c in _casings:
		c.queue_free()

	_casings.clear()
	_casing_next = 0

	var src := gun.get_node(NodePath(casing_node)) as Node3D

	var parts: Array[Dictionary] = []
	_collect_meshes(src, src, parts)

	var bounds: AABB
	for i in parts.size():
		var box: AABB = (parts[i].xform as Transform3D) * (parts[i].mesh as Mesh).get_aabb()
		bounds = box if i == 0 else bounds.merge(box)

	var unit := src.global_transform.basis.get_scale() * weapon.stats.casing_scale
	var size := bounds.size * unit
	var axis := size.max_axis_index()
	var radius := minf(size[(axis + 1) % 3], size[(axis + 2) % 3]) * 0.5

	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = maxf(size[axis], radius * 2.0 + 0.001)

	var shape_basis := Basis.IDENTITY
	if axis == 0:
		shape_basis = Basis(Vector3.BACK, PI * 0.5)
	elif axis == 2:
		shape_basis = Basis(Vector3.RIGHT, PI * 0.5)

	var surface := PhysicsMaterial.new()
	surface.bounce = 0.45
	surface.friction = 0.55

	for i in max_casings:
		var c := Casing.new()
		c.collision_layer = casing_layer
		c.collision_mask = casing_mask
		c.mass = 0.01
		c.continuous_cd = true
		c.linear_damp = 0.05
		c.angular_damp = 1.0
		c.physics_material_override = surface
		c.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON

		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.transform = Transform3D(shape_basis, Vector3.ZERO)

		c.add_child(collider)

		var model := Node3D.new()
		model.transform = Transform3D(Basis.from_scale(unit), -bounds.get_center() * unit)

		c.pivot.add_child(model)

		for part in parts:
			var m := MeshInstance3D.new()
			m.mesh = part.mesh
			m.transform = part.xform
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

			model.add_child(m)

		add_child(c)
		_casings.append(c)


func _collect_meshes(node: Node, root: Node3D, parts: Array[Dictionary]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh != null:
			parts.append({ "mesh": child.mesh, "xform": _relative(child, root) })

		_collect_meshes(child, root, parts)


func _relative(node: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t

		n = n.get_parent()

	return t


func _eject() -> void:
	var s := weapon.stats
	if not s.eject_casings:
		return

	if _casing_gun != weapon.holder.gun:
		_build_casings()

	var xf := weapon.animator.port_transform()
	xf.origin += _current_shift()

	var j := s.eject_jitter
	var v := s.eject_velocity * Vector3(
		randf_range(1.0 - j, 1.0 + j),
		randf_range(1.0 - j, 1.0 + j),
		randf_range(1.0 - j, 1.0 + j),
	)

	var pv := weapon.player.velocity
	var inherited := Vector3(pv.x, pv.y, 0.0)

	var spin := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))

	var c := _casings[_casing_next]
	_casing_next = (_casing_next + 1) % _casings.size()

	c.launch(
		Transform3D(Basis.from_euler(Vector3(randf(), randf(), randf()) * TAU), xf.origin),
		xf.basis * v + inherited,
		spin * s.eject_spin,
		s.casing_lifetime,
	)


func _build_tracers() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE

	for i in tracer_pool:
		var t := Tracer.new()
		t.material = _shader_material(_tracer_shader)
		t.mesh = MeshInstance3D.new()
		t.mesh.mesh = quad
		t.mesh.material_override = t.material
		t.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t.mesh.visible = false

		add_child(t.mesh)
		_tracers.append(t)


func _noise_texture() -> Texture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = 11
	n.frequency = 0.014 * 256.0 / float(noise_size)
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 4
	n.fractal_gain = 0.45

	var img := n.get_seamless_image(noise_size, noise_size, false, false, 0.2, true)
	img.generate_mipmaps()

	return ImageTexture.create_from_image(img)
