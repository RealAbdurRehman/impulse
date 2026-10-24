class_name Weapon
extends Node

signal fired(muzzle: Transform3D)
signal bullet_traced(from: Vector3, to: Vector3, hit: Dictionary)
signal dry_fired
signal fire_mode_changed(automatic: bool)
signal ammo_changed(current: int, capacity: int)
signal reload_started
signal reload_finished
signal aim_changed(aiming: bool)

@export var stats: WeaponStats
@export var holder: GunHolder
@export var character: CharacterMovement

@export var volume_db := 0.0

@export var bullet_force := 18.0

@export var friendly_fire := false

var animator: GunAnimator
var reloader: WeaponReload
var audio: WeaponAudio

var ammo := 0
var automatic := true
var recoil: WeaponRecoil

var chambered := true
var needs_cycle := false

var reload_shells := 0
var reload_total := 0.0

var _aim := 0.0
var _aiming := false
var _bloom := 0.0
var _cooldown := 0.0
var _press_buffer := 0.0
var _recover := 0.0
var _reload_left := 0.0
var _select_left := 0.0

var _exclude: Array[RID] = []
var _linked := false
var _cycling := false
var _reload_queued := false


func _ready() -> void:
	ammo = stats.magazine_size
	automatic = stats.automatic

	animator = GunAnimator.new()
	animator.name = &"GunAnimator"
	add_child(animator)

	var fx := WeaponFx.new()
	fx.name = &"WeaponFx"
	fx.tracer_pool = maxi(fx.tracer_pool, stats.pellets * 2)
	add_child(fx)

	recoil = WeaponRecoil.new()
	recoil.name = &"WeaponRecoil"
	add_child(recoil)

	if stats.reload_by_shell:
		reloader = ShellReload.new()
	else:
		reloader = WeaponReload.new()

	reloader.name = &"WeaponReload"
	add_child(reloader)
	reloader.cued.connect(_on_reload_cue)
	animator.cycle_finished.connect(_on_cycle_finished)

	audio = WeaponAudio.new()
	audio.name = &"WeaponAudio"
	add_child(audio)

	ImpactWorld.of.call_deferred(self)


func reload() -> void:
	if _reload_left > 0.0 or ammo >= stats.magazine_size:
		return

	if _cycling:
		_reload_queued = true
		return

	if stats.reload_by_shell:
		reload_shells = stats.magazine_size - ammo
		reload_total = float(reload_shells) * stats.shell_time + stats.shell_return_time
	else:
		reload_total = stats.reload_time

	_reload_left = reload_total
	reload_started.emit()


func cycle() -> void:
	var spent := needs_cycle
	chambered = ammo > 0
	needs_cycle = false

	_cycling = true
	_cooldown = stats.cycle_back_time + stats.cycle_forward_time
	animator.cycle(spent, chambered)


func switch_fire_mode() -> void:
	if not stats.selector_part or _reload_left > 0.0 or _select_left > 0.0:
		return

	automatic = not automatic
	_select_left = stats.selector_time
	fire_mode_changed.emit(automatic)


func is_reloading() -> bool:
	return _reload_left > 0.0


func _physics_process(delta: float) -> void:
	if not _gun_ready():
		return

	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			if not stats.reload_by_shell:
				ammo = stats.magazine_size
				ammo_changed.emit(ammo, stats.magazine_size)

			reload_finished.emit()
			if stats.chamber_after_reload and stats.auto_cycle and not chambered and ammo > 0:
				cycle()

	var input := character.input
	if input.reload_pressed:
		reload()

	_select_left = maxf(_select_left - delta, 0.0)
	if input.fire_mode_pressed:
		switch_fire_mode()

	_update_aim(delta)

	if input.fire_pressed:
		_press_buffer = stats.trigger_buffer
	else:
		_press_buffer = maxf(_press_buffer - delta, 0.0)

	var pressed := _press_buffer > 0.0
	var held := automatic and not stats.manual_cycle and input.fire

	_bloom = maxf(_bloom - stats.bloom_recovery * delta, 0.0)

	_cooldown -= delta
	_recover = maxf(_recover - delta, 0.0)
	if stats.manual_cycle:
		_manual_step(pressed)
	elif _cooldown <= 0.0 and _reload_left <= 0.0 and _select_left <= 0.0 and (pressed or held):
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


func _manual_step(pressed: bool) -> void:
	var loading := _reload_left > 0.0 and not stats.reload_by_shell
	if _cycling or _cooldown > 0.0 or _select_left > 0.0 or loading:
		return

	if pressed:
		if chambered and ammo > 0:
			_press_buffer = 0.0
			_stop_reload()
			_cooldown += 60.0 / stats.rounds_per_minute
			_shoot()
		elif needs_cycle or ammo > 0:
			_stop_reload()
			if _recover <= 0.0:
				_press_buffer = 0.0
				cycle()
		else:
			_press_buffer = 0.0
			if _reload_left <= 0.0:
				dry_fired.emit()
				if stats.auto_reload:
					reload()

	elif stats.auto_cycle and needs_cycle and _reload_left <= 0.0 and _recover <= 0.0:
		cycle()


func _stop_reload() -> void:
	if _reload_left > 0.0:
		_reload_left = 0.0
		_recover = stats.shell_release_time
		reload_finished.emit()


func _on_cycle_finished() -> void:
	_cycling = false
	_cooldown = maxf(_cooldown, stats.cycle_settle_time)
	if _reload_queued:
		_reload_queued = false
		reload()


func _on_reload_cue(cue: WeaponReload.Cue) -> void:
	if stats.reload_by_shell and cue == WeaponReload.Cue.SEAT:
		ammo = mini(ammo + 1, stats.magazine_size)
		ammo_changed.emit(ammo, stats.magazine_size)


func _update_aim(delta: float) -> void:
	var want := character.input.aim and _reload_left <= 0.0
	want = want and not (stats.ads_breaks_on_cycle and _cycling)
	if want != _aiming:
		_aiming = want
		aim_changed.emit(want)

	_aim = move_toward(_aim, 1.0 if want else 0.0, delta / maxf(stats.ads_time, 0.01))

	character.aim_amount = smoothstep(0.0, 1.0, _aim)
	character.aim_speed_scale = lerpf(1.0, stats.ads_move_scale, character.aim_amount)
	character.aim_zoom = lerpf(1.0, stats.ads_zoom, character.aim_amount)
	character.aim_look = lerpf(1.0, stats.ads_look, character.aim_amount)


func _gun_ready() -> bool:
	if not holder.gun.is_inside_tree():
		return false

	if not _linked:
		_linked = true
		for c in holder.ragdoll.get_children():
			if c is PhysicalBone3D:
				_exclude.append(c.get_rid())
				for k in c.get_children():
					if k is Area3D:
						_exclude.append(k.get_rid())

	return true


func bullet_ray() -> Array[Vector3]:
	var muzzle := holder.muzzle_transform()
	var origin := muzzle.origin
	origin.z = character.plane_z

	var forward := Vector3(muzzle.basis.x.x, muzzle.basis.x.y, 0.0).normalized()
	forward = forward.rotated(Vector3.BACK, recoil.aim_correction())

	var lift := holder.spine.barrel.lift
	if lift > 0.0 and character.input.has_aim:
		var to_aim := character.aim_point - origin
		var toward := Vector3(to_aim.x, to_aim.y, 0.0).normalized()
		forward = forward.slerp(toward, smoothstep(0.0, 0.2, lift))

	return [origin, forward]


func _shoot() -> void:
	ammo -= 1
	if stats.manual_cycle:
		chambered = false
		needs_cycle = true

	_bloom = minf(_bloom + stats.bloom_per_shot, stats.bloom_max)

	var muzzle := holder.muzzle_transform()
	var ray := bullet_ray()
	var origin := ray[0]
	var forward := ray[1]

	fired.emit(muzzle)
	for i in stats.pellets:
		_trace(origin, _pellet_direction(forward, i))

	ammo_changed.emit(ammo, stats.magazine_size)


func spread_cone() -> float:
	var base := stats.spread_degrees + _bloom
	return deg_to_rad(base * lerpf(1.0, stats.ads_spread_scale, character.aim_amount))


func _pellet_direction(dir: Vector3, index: int) -> Vector3:
	var cone := spread_cone()
	if stats.pellets == 1:
		return dir.rotated(Vector3.BACK, cone * (randf() + randf() - 1.0))

	var slot := (float(index) + lerpf(0.5, randf(), stats.pellet_jitter)) / float(stats.pellets)
	return dir.rotated(Vector3.BACK, cone * (slot * 2.0 - 1.0))


const FAN: Array[float] = [0.0, 0.05, -0.05, 0.1, -0.1, 0.15, -0.15]


func _cast(origin: Vector3, end: Vector3, exclude: Array[RID]) -> Dictionary:
	var space := holder.gun.get_world_3d().direct_space_state
	var best := { }
	var nearest := INF
	for z in FAN:
		var query := PhysicsRayQueryParameters3D.create(
			origin + Vector3(0.0, 0.0, z),
			end + Vector3(0.0, 0.0, z),
			stats.hit_mask | Hitboxes.LAYER,
			exclude,
		)
		query.collide_with_areas = true

		var hit := space.intersect_ray(query)
		var skipped := exclude
		while not hit.is_empty() and _is_friend(hit.collider):
			if skipped.size() == exclude.size():
				skipped = exclude.duplicate()

			skipped.append(hit.rid)
			query.exclude = skipped
			hit = space.intersect_ray(query)

		if hit.is_empty():
			continue

		var d := origin.distance_squared_to(hit.position)
		if d < nearest:
			nearest = d
			best = hit

	return best


func _is_friend(collider: Object) -> bool:
	var other := Health.of(collider)
	return not friendly_fire and other != null and other.team != &"" and other.team == character.health.team


const MAX_PASSES := 12
const REFERENCE_DAMAGE := 25.0


func _trace(origin: Vector3, dir: Vector3) -> void:
	var end := origin + dir * stats.max_range
	var skip := _exclude.duplicate()
	var reach := stats.penetration
	var from := origin
	var first := { }
	var struck := { }
	var world := ImpactWorld.of(self)

	for i in MAX_PASSES:
		var hit := _cast(from, origin + dir * stats.max_range, skip)
		if hit.is_empty():
			break

		if first.is_empty():
			first = hit

		if struck.is_empty() and Health.of(hit.collider) != null:
			struck = hit

		var power := lerpf(0.4, 1.0, reach / stats.penetration)
		_apply_hit(hit, dir, origin.distance_to(hit.position), power)

		var surface := Surfaces.of(hit.collider)
		var resistance := Surfaces.style(surface).resistance
		var size := clampf(sqrt(stats.damage * power / REFERENCE_DAMAGE), 0.5, 2.2)
		world.strike(hit.position, hit.normal, dir, surface, size)

		var depth := reach / resistance
		var exit := _exit(hit, dir, depth, skip)
		_pass_through(hit, skip)

		if exit.is_empty():
			end = hit.position + dir * depth
			break

		world.strike(exit.position, exit.normal, dir, surface, size * 0.7, true)

		reach -= hit.position.distance_to(exit.position) * resistance
		from = exit.position + dir * 0.01
		from.z = character.plane_z

	bullet_traced.emit(origin, end, struck if not struck.is_empty() else first)


func _exit(hit: Dictionary, dir: Vector3, depth: float, skip: Array[RID]) -> Dictionary:
	var space := holder.gun.get_world_3d().direct_space_state
	var ignore := skip.duplicate()
	var start: Vector3 = hit.position

	for i in MAX_PASSES:
		var query := PhysicsRayQueryParameters3D.create(
			start + dir * depth,
			start + dir * 0.002,
			stats.hit_mask | Hitboxes.LAYER,
			ignore,
		)
		query.collide_with_areas = true

		var found := space.intersect_ray(query)
		if found.is_empty() or found.rid == hit.rid:
			return found

		ignore.append(found.rid)

	return { }


func _pass_through(hit: Dictionary, skip: Array[RID]) -> void:
	skip.append(hit.rid)

	var bone := Hitboxes.bone_of(hit.collider)
	if bone == null:
		return

	skip.append(bone.get_rid())
	for child in bone.get_children():
		if child is Area3D:
			skip.append(child.get_rid())


func _apply_hit(hit: Dictionary, dir: Vector3, distance: float, power: float) -> void:
	var collider := hit.collider as Node3D
	var body: Node3D = Hitboxes.bone_of(collider)
	if body == null:
		body = collider

	var point: Vector3 = hit.position
	var health := Health.of(collider)

	var force := 1.0
	if health != null:
		force = bullet_force * health.impulse_scale()

	var impulse := dir * stats.impact_impulse * force * power
	if health != null:
		health.hit(_damage_at(distance) * power, point, dir, body as PhysicalBone3D, impulse.length())

	var ragdoll := body.get_parent() as ActiveRagdoll
	if ragdoll != null:
		ragdoll.kick(body as PhysicalBone3D, impulse, point - body.global_position)
	elif body.has_method(&"apply_impulse"):
		body.call(&"apply_impulse", impulse, point - body.global_position)


func _damage_at(distance: float) -> float:
	if stats.falloff_end <= stats.falloff_start:
		return stats.damage

	var k := smoothstep(stats.falloff_start, stats.falloff_end, distance)
	return stats.damage * lerpf(1.0, stats.falloff_floor, k)
