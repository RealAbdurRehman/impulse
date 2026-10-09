class_name Weapon
extends Node

signal fired(muzzle: Transform3D)
signal bullet_traced(from: Vector3, to: Vector3, hit: Dictionary)
signal dry_fired
signal ammo_changed(current: int, capacity: int)
signal reload_started
signal reload_finished

@export var stats: WeaponStats
@export var holder: GunHolder
@export var player: PlayerMovement

@export_group("Input")
@export var fire_action: StringName = &"shoot"
@export var reload_action: StringName = &"reload"

var animator: GunAnimator
var reloader: WeaponReload

var ammo := 0
var recoil: WeaponRecoil

var _cooldown := 0.0
var _press_buffer := 0.0
var _reload_left := 0.0

var _exclude: Array[RID] = []
var _linked := false


func _ready() -> void:
	ammo = stats.magazine_size

	animator = GunAnimator.new()
	animator.name = &"GunAnimator"
	add_child(animator)

	var fx := WeaponFx.new()
	fx.name = &"WeaponFx"
	add_child(fx)

	recoil = WeaponRecoil.new()
	recoil.name = &"WeaponRecoil"
	add_child(recoil)

	reloader = WeaponReload.new()
	reloader.name = &"WeaponReload"
	add_child(reloader)


func reload() -> void:
	if _reload_left > 0.0 or ammo >= stats.magazine_size:
		return

	_reload_left = stats.reload_time
	reload_started.emit()


func is_reloading() -> bool:
	return _reload_left > 0.0


func _physics_process(delta: float) -> void:
	if not _gun_ready():
		return

	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			ammo = stats.magazine_size
			ammo_changed.emit(ammo, stats.magazine_size)
			reload_finished.emit()

	if Input.is_action_just_pressed(reload_action):
		reload()

	if Input.is_action_just_pressed(fire_action):
		_press_buffer = stats.trigger_buffer
	else:
		_press_buffer = maxf(_press_buffer - delta, 0.0)

	var pressed := _press_buffer > 0.0
	var held := stats.automatic and Input.is_action_pressed(fire_action)

	_cooldown -= delta
	if _cooldown <= 0.0 and _reload_left <= 0.0 and (pressed or held):
		_press_buffer = 0.0
		if ammo > 0:
			_cooldown += 60.0 / stats.rounds_per_minute
			_shoot()
		else:
			if pressed:
				dry_fired.emit()

			if stats.auto_reload:
				reload()

	_cooldown = maxf(_cooldown, 0.0)


func _gun_ready() -> bool:
	if not holder.gun.is_inside_tree():
		return false

	if not _linked:
		_linked = true
		for c in holder.ragdoll.get_children():
			if c is PhysicalBone3D:
				_exclude.append(c.get_rid())

	return true


func _shoot() -> void:
	ammo -= 1

	var muzzle := holder.muzzle_transform()
	var origin := muzzle.origin
	origin.z = player.plane_z

	var forward := Vector3(muzzle.basis.x.x, muzzle.basis.x.y, 0.0).normalized()
	forward = forward.rotated(Vector3.BACK, recoil.aim_correction())

	fired.emit(muzzle)
	for i in stats.pellets:
		_trace(origin, _with_spread(forward))

	ammo_changed.emit(ammo, stats.magazine_size)


func _with_spread(dir: Vector3) -> Vector3:
	var angle := deg_to_rad(stats.spread_degrees) * (randf() + randf() - 1.0)
	return dir.rotated(Vector3.BACK, angle)


func _trace(origin: Vector3, dir: Vector3) -> void:
	var end := origin + dir * stats.max_range
	var query := PhysicsRayQueryParameters3D.create(origin, end, stats.hit_mask, _exclude)
	var hit := holder.gun.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		bullet_traced.emit(origin, end, hit)
		return

	_apply_hit(hit, dir)
	bullet_traced.emit(origin, hit.position, hit)


func _apply_hit(hit: Dictionary, dir: Vector3) -> void:
	var body := hit.collider as Node3D
	var point: Vector3 = hit.position
	if body.has_method(&"take_damage"):
		body.call(&"take_damage", stats.damage, point, dir)

	if body.has_method(&"apply_impulse"):
		body.call(&"apply_impulse", dir * stats.impact_impulse, point - body.global_position)
