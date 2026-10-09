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


const FLASH_SPREAD := 1.7
const PUFF_STEP := 0.03

@export var casing_node: StringName = &"BulletCasing"

@export_group("Pools")
@export var sprite_pool := 90
@export var max_casings := 40
@export var tracer_pool := 12
@export var puff_pool := 90

@export_flags_3d_physics var casing_layer := 4
@export_flags_3d_physics var casing_mask := 1

var weapon: Weapon

var _noise: Texture2D
var _flash_shader: Shader
var _smoke_shader: Shader
var _tracer_shader: Shader

var _anchor: Node3D
var _shift := Vector3.ZERO
var _flash_root: Node3D
var _flash: MeshInstance3D
var _light: OmniLight3D
var _flash_left := 0.0
var _flash_total := 0.05

var _sprites: Array[Sprite] = []
var _sprite_next := 0
var _heat := 0.0
var _puffs: Array[Sprite] = []
var _puff_next := 0
var _puff_timer := 0.0
var _puff_clock := 0.0
var _puff_phase := 0.0

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
	_noise = _noise_texture()

	_build_sprites()
	_build_tracers()

	weapon.fired.connect(_on_fired)
	weapon.bullet_traced.connect(_on_bullet_traced)
	weapon.animator.ejected.connect(_eject)


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

	_heat = minf(_heat + weapon.stats.barrel_heat_per_shot, 1.0)
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
		_light.visible = false
		return false

	var t := 1.0 - _flash_left / _flash_total
	_apply_flash_level(1.0 - smoothstep(0.88, 1.0, t), t)
	_place_light()

	return true


func _apply_flash_level(level: float, age: float) -> void:
	var m := _flash.material_override as ShaderMaterial
	m.set_shader_parameter("level", level)
	m.set_shader_parameter("age", age)
	m.set_shader_parameter("fade", smoothstep(0.5, 1.0, age))
	_light.light_energy = weapon.stats.light_energy * (1.0 - smoothstep(0.3, 1.0, age))


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

	for i in puff_pool:
		_puffs.append(_make_sprite(quad))


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


func _take_puff() -> Sprite:
	var sp := _puffs[_puff_next]
	_puff_next = (_puff_next + 1) % _puffs.size()

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
	pos.z += fmod(float(_sprite_next + _puff_next), 30.0) * 0.004

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
	sp.material.set_shader_parameter("density", density)
	sp.material.set_shader_parameter("age", 0.0)

	set_process(true)


func _update_sprites(delta: float) -> bool:
	var a := _step_sprites(_sprites, delta)
	var b := _step_sprites(_puffs, delta)

	return a or b


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

	_spawn_sprite(
		_take_sprite(),
		o + dir * 0.15 * k,
		dir.rotated(Vector3.BACK, randf_range(-0.1, 0.1)),
		Vector2(0.5, 0.2) * k,
		Vector2(1.5, 0.4) * k,
		life * 0.7,
		dir * drift * 1.6,
		3.0,
		up * 0.1,
		s.smoke_opacity,
		Vector2(1.1, 0.5),
		Vector2(0.3, 0.04),
	)

	_spawn_sprite(
		_take_sprite(),
		o + dir * 0.4 * k,
		dir.rotated(Vector3.BACK, randf_range(-0.15, 0.15)),
		Vector2(1.0, 0.3) * k,
		Vector2(2.6, 0.65) * k,
		life,
		dir * drift * 0.8,
		1.6,
		up * 0.18,
		s.smoke_opacity * 0.7,
		Vector2(1.0, 0.45),
		Vector2(0.2, 0.06),
	)

	_spawn_sprite(
		_take_sprite(),
		o + dir * 0.6 * k,
		dir.rotated(Vector3.BACK, randf_range(-0.25, 0.25)),
		Vector2(1.3, 0.4) * k,
		Vector2(3.0, 0.8) * k,
		life * 1.15,
		dir * drift * 0.45,
		1.3,
		up * 0.22,
		s.smoke_opacity * 0.5,
		Vector2(0.9, 0.4),
		Vector2(0.12, 0.05),
	)


func _update_wisps(delta: float) -> bool:
	var s := weapon.stats
	_heat = maxf(_heat - delta / maxf(s.barrel_cool_time, 0.1), 0.0)

	if _heat < 0.05 or s.barrel_heat_per_shot <= 0.0:
		_puff_phase = randf() * TAU
		return false

	_puff_clock += delta
	_puff_timer -= delta
	if _puff_timer > 0.0:
		return true

	var xf := _anchor.get_global_transform_interpolated()
	var fwd := Vector3(xf.basis.x.x, xf.basis.x.y, 0.0).normalized()
	var heat := sqrt(_heat)
	var wave := sin(_puff_clock * 2.6 + _puff_phase)

	while _puff_timer <= 0.0:
		_puff_timer += PUFF_STEP

		var size := s.barrel_smoke_size * randf_range(0.8, 1.2)
		var life := s.barrel_smoke_lifetime * randf_range(0.85, 1.15)
		var spin := Vector3.RIGHT.rotated(Vector3.BACK, randf() * TAU)

		_spawn_sprite(
			_take_puff(),
			xf.origin + fwd * 0.012 + Vector3(randf_range(-0.004, 0.004), 0.0, 0.0),
			spin,
			Vector2.ONE * size * 0.25,
			Vector2.ONE * size,
			life,
			fwd * 0.06 + Vector3(randf_range(-0.02, 0.02), s.barrel_smoke_rise, 0.0),
			0.5,
			Vector3(wave * 0.07, 0.05, 0.0),
			s.barrel_smoke_opacity * heat * 0.3,
			Vector2(0.9, 0.9),
			Vector2(0.15, 0.05),
		)

	return true


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
	n.frequency = 0.014
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 3
	n.fractal_gain = 0.45

	var img := n.get_seamless_image(256, 256, false, false, 0.2, true)
	img.generate_mipmaps()

	return ImageTexture.create_from_image(img)
