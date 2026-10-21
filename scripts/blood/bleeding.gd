class_name Bleeding
extends Node

const BODY_SHADER := preload("res://scripts/blood/shaders/blood_body.gdshader")
const MAX_WOUNDS := 12

@export var amount := 0.2

@export_group("Wounds")
@export var spatter_reach := 0.1
@export var drip_time := Vector2(3.0, 9.0)
@export var drip_rate := 6.0


class Wounds:
	var materials: Array[ShaderMaterial] = []
	var pos := PackedVector4Array()
	var info := PackedVector4Array()
	var count := 0
	var next := 0


class Bleeder:
	var bone: PhysicalBone3D
	var local := Vector3.ZERO
	var out := Vector3.ZERO
	var last := Vector3.ZERO
	var total := 0.0
	var left := 0.0
	var rate := 0.0
	var pump := 0.0
	var beat := 0.0
	var carry := 0.0


var health: Health

var _world: BloodWorld
var _wounds := { }
var _bleeders: Array[Bleeder] = []


func _ready() -> void:
	health = get_parent() as Health
	health.damaged.connect(_on_damaged)
	health.corpse_struck.connect(_on_corpse_struck)
	add_to_group(&"bleeding")
	set_physics_process(false)
	_prepare.call_deferred()


func _prepare() -> void:
	_world = BloodWorld.of(self)


func tick(clock: float) -> void:
	for wounds: Wounds in _wounds.values():
		for material in wounds.materials:
			material.set_shader_parameter("clock", clock)


func fade(level: float) -> void:
	for wounds: Wounds in _wounds.values():
		for material in wounds.materials:
			material.set_shader_parameter("fade", level)


func _on_damaged(damage: float, point: Vector3, direction: Vector3, bone: PhysicalBone3D) -> void:
	_strike(damage, point, direction, bone, health.current <= 0.0, false)


func _on_corpse_struck(
	damage: float,
	point: Vector3,
	direction: Vector3,
	bone: PhysicalBone3D,
) -> void:
	_strike(damage, point, direction, bone, false, true)


func _strike(
	damage: float,
	point: Vector3,
	direction: Vector3,
	bone: PhysicalBone3D,
	lethal: bool,
	corpse: bool,
) -> void:
	if amount <= 0.0:
		return

	var force := clampf(damage / 25.0, 0.3, 4.0) * amount * (0.7 if corpse else 1.0)
	var dir := Vector3(direction.x, direction.y, 0.0).normalized()
	var exit := _exit(bone, point, dir)
	var speed := 1.0 + float(lethal) * 0.5

	_world.cloud(point, -dir, 0.22 + 0.1 * force, 1, 0.6, 0.8, 0.7)
	_world.jet(
		point,
		-dir + Vector3.UP * 0.1,
		4 + int(5.0 * force),
		Vector2(1.5, 4.5),
		0.55,
		Vector2(0.004, 0.012),
	)

	_world.cloud(exit, dir, 0.42 + 0.16 * force, 1 + int(force * speed), 0.9, 1.6, 0.85)
	_world.jet(
		exit,
		dir,
		14 + int(16.0 * force * speed),
		Vector2(2.0, 6.5) * speed,
		0.4,
		Vector2(0.004, 0.013),
		Vector3.ZERO,
		0.3,
	)
	_world.jet(exit, dir, 3 + int(force * 2.0), Vector2(2.0, 6.0), 0.7, Vector2(0.009, 0.016))
	_world.wall_spatter(exit, dir, 1 + int(force) + int(lethal))

	_wound(bone, point, 0.055 + 0.025 * force, 0.0)
	_wound(bone, exit, 0.08 + 0.035 * force, 0.12 + 0.05 * force)
	for i in 2 + int(force * 2.0):
		_spatter(point.lerp(exit, randf()))

	var time := drip_time.y if lethal else lerpf(drip_time.x, drip_time.y, 0.25)
	time *= 0.5 if corpse else 1.0
	_bleed(bone, exit, dir, time, drip_rate * (0.5 + 0.25 * force), 1.0 if lethal else 0.0)
	_bleed(bone, point, -dir, time * 0.6, drip_rate * 0.4, 0.0)


func _exit(bone: PhysicalBone3D, point: Vector3, dir: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(
		point + dir * 0.7,
		point + dir * 0.01,
		Hitboxes.LAYER,
	)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := bone.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and Hitboxes.bone_of(hit.collider) == bone:
		return hit.position

	return point + dir * 0.12


func _spatter(near: Vector3) -> void:
	var at := near + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * spatter_reach
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(at.x, at.y, 1.2),
		Vector3(at.x, at.y, -1.2),
		Hitboxes.LAYER,
	)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := _world.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or Health.of(hit.collider) != health:
		return

	_wound(
		Hitboxes.bone_of(hit.collider),
		hit.position,
		randf_range(0.02, 0.055),
		randf_range(0.0, 0.14),
	)


func _wound(bone: PhysicalBone3D, point: Vector3, radius: float, streak: float) -> void:
	var wounds := _wounds_of(bone)
	var local := bone.global_transform.affine_inverse() * point
	wounds.pos[wounds.next] = Vector4(local.x, local.y, local.z, radius)
	wounds.info[wounds.next] = Vector4(
		_world.clock,
		randf() * 10.0 + 1.0,
		streak,
		randf_range(0.18, 0.4),
	)
	wounds.next = (wounds.next + 1) % MAX_WOUNDS
	wounds.count = mini(wounds.count + 1, MAX_WOUNDS)

	for material in wounds.materials:
		material.set_shader_parameter("wound_pos", wounds.pos)
		material.set_shader_parameter("wound_info", wounds.info)
		material.set_shader_parameter("wound_count", wounds.count)


func _wounds_of(bone: PhysicalBone3D) -> Wounds:
	if _wounds.has(bone):
		return _wounds[bone]

	var wounds := Wounds.new()
	wounds.pos.resize(MAX_WOUNDS)
	wounds.info.resize(MAX_WOUNDS)

	var to_bone := bone.global_transform.affine_inverse()
	for node in bone.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.visible or not (mesh.name == &"Look" or BodyLook.KEPT.has(mesh.name)):
			continue

		var material := ShaderMaterial.new()
		material.shader = BODY_SHADER
		material.set_shader_parameter("to_bone", to_bone * mesh.global_transform)
		material.set_shader_parameter("clock", _world.clock)
		mesh.material_overlay = material
		wounds.materials.append(material)

	_wounds[bone] = wounds
	return wounds


func _bleed(
	bone: PhysicalBone3D,
	point: Vector3,
	dir: Vector3,
	time: float,
	rate: float,
	pump: float,
) -> void:
	var bleeder := Bleeder.new()
	bleeder.bone = bone
	bleeder.local = bone.global_transform.affine_inverse() * point
	bleeder.out = bone.global_transform.basis.inverse() * dir
	bleeder.last = point
	bleeder.total = time
	bleeder.left = time
	bleeder.rate = rate
	bleeder.pump = pump
	_bleeders.append(bleeder)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	var i := 0
	while i < _bleeders.size():
		var b := _bleeders[i]
		b.left -= delta
		if b.left <= 0.0:
			_bleeders.remove_at(i)
			continue

		i += 1
		var k := b.left / b.total
		var at := b.bone.global_transform * b.local
		var vel := (at - b.last) / maxf(delta, 0.0001)
		b.last = at
		var out := (b.bone.global_transform.basis * b.out).normalized()

		b.carry += b.rate * (0.2 + 0.8 * k) * delta
		while b.carry >= 1.0:
			b.carry -= 1.0
			var kick := out * randf_range(0.1, 0.5) + Vector3(
				randf_range(-0.2, 0.2),
				0.0,
				randf_range(-0.2, 0.2),
			)
			_world.drops.spawn(at, vel * 0.5 + kick, randf_range(0.006, 0.012), true)

		if b.pump > 0.0:
			b.beat += delta * (0.9 + 0.5 * k)
			if b.beat >= 1.0:
				b.beat -= 1.0
				var strength := b.pump * amount * k
				_world.jet(
					at,
					(out + Vector3.UP * 0.35).normalized(),
					5 + int(14.0 * strength),
					Vector2(1.5, 5.0 + 2.0 * strength),
					0.28,
					Vector2(0.005, 0.014),
					vel * 0.5,
				)
				_world.cloud(at, out, 0.18 + 0.1 * strength, 1, 0.5, 0.6, 0.4)

	if _bleeders.is_empty():
		set_physics_process(false)
