class_name EnemyGunner
extends RefCounted

var rng := RandomNumberGenerator.new()

var skill := 0.5
var discipline := 0.5
var patience := 0.5
var composure := 0.5

var aim_point := Vector3.ZERO
var settled := 0.0

var _gaze := Vector3.ZERO
var _height := 1.2
var _height_left := 0.0
var _drift := Vector2.ZERO
var _drift_goal := Vector2.ZERO
var _drift_left := 0.0
var _kick := Vector2.ZERO

var _plan: Array[Vector2] = []
var _step_left := 0.0
var _pause_left := 0.0
var _last_ammo := -1
var _reload_at := -1


func look_ahead(from: Vector3, facing: int) -> void:
	_gaze = from + Vector3(float(facing) * 8.0, 0.0, 0.0)
	settled = 0.0


func aim(delta: float, from: Vector3, at: Vector3, crouching: bool, moving: bool, scoped: bool, braced := false) -> Vector3:
	_height_left -= delta
	if _height_left <= 0.0:
		_height = _pick_height()
		_height_left = rng.randf_range(1.2, 3.5)

	var want := at + Vector3.UP * _height * (0.7 if crouching else 1.0)
	var distance := from.distance_to(want)

	var degrees := lerpf(5.0, 1.0, skill)
	degrees *= 1.0 + (1.0 - clampf(settled / 1.5, 0.0, 1.0)) * 0.8
	degrees *= 1.4 if moving else 1.0
	degrees *= 0.6 if scoped else 1.0
	degrees *= 0.8 if braced else 1.0
	var radius := distance * tan(deg_to_rad(degrees))

	_drift_left -= delta
	if _drift_left <= 0.0:
		_drift_goal = Vector2(rng.randfn(0.0, 0.6), rng.randfn(0.0, 0.6)) * radius
		_drift_left = rng.randf_range(0.25, 0.8)

	_drift = _drift.lerp(_drift_goal, 1.0 - exp(-4.0 * delta))
	_kick *= exp(-5.0 * delta)

	var offset := _drift + _kick
	var desired := want + Vector3(offset.x, offset.y, 0.0)
	_gaze = _gaze.lerp(desired, 1.0 - exp(-lerpf(3.0, 10.0, skill) * delta))
	aim_point = _gaze

	var close := maxf(0.3, radius * 1.5)
	settled = settled + delta if _gaze.distance_to(want) < close else maxf(settled - delta, 0.0)
	return aim_point


func flinch(distance: float) -> void:
	var shake := lerpf(1.4, 0.5, composure)
	_kick += Vector2(rng.randfn(0.0, 0.08), rng.randfn(0.0, 0.08)) * distance * shake
	_plan.clear()
	_pause_left = maxf(_pause_left, rng.randf_range(0.2, 0.5) * shake)


var rounds := 0


func firing_done() -> bool:
	for step in _plan:
		if step.y > 0.5:
			return false

	return true


func trigger(delta: float, may_fire: bool, weapon: Weapon) -> bool:
	var shots := 0
	if _last_ammo >= 0:
		shots = maxi(_last_ammo - weapon.ammo, 0)

	_last_ammo = weapon.ammo
	rounds += shots
	if shots > 0:
		_kick += Vector2(rng.randfn(0.0, 0.03), absf(rng.randfn(0.04, 0.03)))

	if not may_fire or weapon.ammo <= 0:
		if not _plan.is_empty():
			_plan.clear()
			_pause_left = maxf(_pause_left, rng.randf_range(0.15, 0.45))

		_pause_left = maxf(_pause_left - delta, 0.0)
		return false

	if _pause_left > 0.0:
		_pause_left -= delta
		return false

	if _plan.is_empty():
		_plan_burst(weapon)
		_step_left = _plan[0].x

	var step := _plan[0]
	_step_left -= delta
	if _step_left <= 0.0:
		_plan.pop_front()
		if _plan.is_empty():
			return false

		_step_left = _plan[0].x
		step = _plan[0]

	return step.y > 0.5


func wants_reload(weapon: Weapon, quiet: bool, lull: bool) -> bool:
	if weapon.is_reloading() or weapon.ammo >= weapon.stats.magazine_size:
		return false

	if weapon.ammo <= 0 or quiet:
		return true

	if _reload_at < 0:
		_reload_at = int(float(weapon.stats.magazine_size) * rng.randf_range(0.0, 0.35))

	return lull and weapon.ammo <= _reload_at


func reloaded() -> void:
	_reload_at = -1


func _pick_height() -> float:
	var roll := rng.randf()
	var head := lerpf(0.08, 0.2, skill)
	if roll < head:
		return 1.62

	if roll < head + 0.5:
		return 1.25

	if roll < head + 0.8:
		return 0.95

	return 0.6


func _plan_burst(weapon: Weapon) -> void:
	var stats := weapon.stats
	var span := 60.0 / stats.rounds_per_minute
	var pause := rng.randf_range(0.5, 1.4) * (1.5 - skill * 0.7) * lerpf(0.8, 1.5, patience)
	if rng.randf() < 0.15:
		pause *= 2.2

	if stats.manual_cycle:
		_plan_manual(weapon, pause * (0.5 if stats.pellets > 1 else 1.0))
		return

	if stats.automatic:
		var count := clampi(roundi(rng.randfn(lerpf(5.5, 3.0, discipline), lerpf(2.2, 0.8, discipline))), 1, 9)
		if rng.randf() < 0.08:
			count += rng.randi_range(3, 6)

		count = mini(count, weapon.ammo)
		_plan.append(Vector2(float(count) * span, 1.0))
		_plan.append(Vector2(pause, 0.0))
		return

	for i in rng.randi_range(1, 3):
		_plan.append(Vector2(0.06, 1.0))
		_plan.append(Vector2(maxf(span, 0.22 * exp(rng.randfn(0.0, 0.3))), 0.0))

	_plan.append(Vector2(pause, 0.0))


func _plan_manual(weapon: Weapon, pause: float) -> void:
	var stats := weapon.stats
	var cycle := stats.cycle_back_time + stats.cycle_forward_time + stats.cycle_settle_time + 0.15

	if weapon.needs_cycle and not stats.auto_cycle:
		_plan.append(Vector2(0.06, 1.0))
		_plan.append(Vector2(cycle, 0.0))
		return

	_plan.append(Vector2(0.06, 1.0))
	if stats.auto_cycle:
		_plan.append(Vector2(cycle, 0.0))
	else:
		_plan.append(Vector2(rng.randf_range(0.25, 0.6), 0.0))
		_plan.append(Vector2(0.06, 1.0))
		_plan.append(Vector2(cycle, 0.0))

	_plan.append(Vector2(pause + 0.4, 0.0))
