class_name GunAnimator
extends Node


class Part:
	var node: Node3D
	var rest := Transform3D.IDENTITY


enum Phase {
	IDLE,
	BACK,
	SETTLE,
	LOCKED,
	FORWARD,
	BOUNCE,
	DRIVEN,
}

signal ejected
signal slide_locked
signal selector_clicked
signal cycled_back
signal cycled_forward
signal cycle_finished

@export_group("Ejection")
@export_range(0.05, 0.9) var eject_at := 0.35

@export_group("Feel")
@export var lock_settle_time := 0.04
@export var bounce_height := 0.05
@export var bounce_time := 0.04

@export_range(0.05, 0.5) var barrel_follow := 0.16

@export var lever_speed := 45.0
@export var trigger_pull_speed := 70.0
@export var trigger_release_speed := 22.0
@export var trigger_hold := 0.09

@export var cover_time := 0.08

@export_range(0.05, 0.6) var selector_reach := 0.35
@export_range(0.2, 0.95) var selector_land := 0.7

var weapon: Weapon

var _gun: Node3D
var _scale := 1.0

var _slide: Array[Part] = []
var _barrel: Array[Part] = []
var _trigger: Part
var _stop: Part
var _handle: Part
var _cover: Part
var _selector: Part
var _pivot := Vector3.ZERO
var _port := Transform3D.IDENTITY
var _round: Node3D
var _feed_half := 0.0
var _feed_center := Vector3.ZERO
var _feed_head := 0.0
var _feed_breech := 0.0
var _feed_from := Vector3.ZERO
var _feed_to := Vector3.ZERO
var _feed_from_angle := 0.0
var _feed_to_angle := 0.0
var _feeding := false
var _ejected := false
var _feed_forced := false
var _manual := false
var _cycle_feed := false
var _eject_wanted := true
var _eject_at := 0.35
var _back_time := 0.03
var _forward_time := 0.065

var _phase := Phase.IDLE
var _lock := false
var _t := 0.0
var _from := 0.0
var _duration := 0.05

var _s := 0.0
var _h := 0.0
var _cover_t := -1.0
var _lever := 0.0
var _pull := 0.0
var _hold := 0.0

var _sel := 0.0
var _sel_from := 0.0
var _sel_to := 0.0
var _sel_t := -1.0
var _sel_hit := false
var _reach := 0.0


func _ready() -> void:
	weapon = get_parent() as Weapon
	weapon.fired.connect(_on_fired)
	weapon.dry_fired.connect(_on_dry_fired)
	weapon.ammo_changed.connect(_on_ammo_changed)
	weapon.reload_finished.connect(_on_reload_finished)
	weapon.fire_mode_changed.connect(_on_fire_mode_changed)


func _physics_process(delta: float) -> void:
	if not _resolve():
		return

	_step_slide(delta)
	_step_controls(delta)
	_step_cover(delta)
	_step_selector(delta)

	if _phase != Phase.DRIVEN:
		_h = minf(_h, _s)

	_apply()

	if _settled():
		set_physics_process(false)


func _on_fired(_muzzle: Transform3D) -> void:
	_resolve()

	_hold = trigger_hold
	_open_cover()

	if weapon.stats.manual_cycle:
		set_physics_process(true)
		return

	_lock = weapon.ammo <= 0 and weapon.stats.slide_lock
	_feed_forced = false
	_start_stroke(
		false,
		weapon.stats.slide_back_time,
		weapon.stats.slide_forward_time,
		eject_at,
		true,
	)
	set_physics_process(true)


func _on_dry_fired() -> void:
	_hold = trigger_hold
	set_physics_process(true)


func _on_ammo_changed(current: int, _capacity: int) -> void:
	if current > 0:
		_release()


func _on_reload_finished() -> void:
	_release()


func _on_fire_mode_changed(automatic: bool) -> void:
	_resolve()

	_sel_from = _sel
	_sel_to = 1.0 if automatic else 0.0
	_sel_t = 0.0
	_sel_hit = false
	set_physics_process(true)


func release_slide() -> void:
	_feed_forced = true
	_lock = false
	if _phase == Phase.LOCKED or _phase == Phase.SETTLE or _phase == Phase.DRIVEN:
		_begin_forward(weapon.stats.slide_release_time)
		set_physics_process(true)


func cycle(eject: bool, feed: bool) -> void:
	_resolve()

	var stats := weapon.stats
	_lock = false
	_cycle_feed = feed
	_start_stroke(
		true,
		stats.cycle_back_time,
		stats.cycle_forward_time,
		stats.cycle_eject_at,
		eject,
	)
	set_physics_process(true)


func _start_stroke(manual: bool, back: float, forward: float, at: float, eject: bool) -> void:
	_manual = manual
	_back_time = back
	_forward_time = forward
	_eject_at = at
	_eject_wanted = eject
	_ejected = false

	_phase = Phase.BACK
	_t = 0.0
	_from = _s


func drive_slide(value: float, handle := value) -> void:
	_lock = false
	_phase = Phase.DRIVEN
	_s = value
	_h = handle
	_open_cover()
	set_physics_process(true)


func slide_position() -> float:
	return _s


func rack_position() -> float:
	return _s if _handle == null else _h


func rack_node() -> Node3D:
	_resolve()
	return (_slide[0] if _handle == null else _handle).node


func rack_rest() -> Transform3D:
	return (_slide[0] if _handle == null else _handle).rest


func port_transform() -> Transform3D:
	var travel := 0.0 if weapon.stats.manual_cycle else weapon.stats.slide_travel / _scale
	var local := _port.origin + Vector3(-travel * _s, 0.0, 0.0)
	var basis := _gun.global_transform.basis.orthonormalized() * _port.basis.orthonormalized()
	return Transform3D(basis, _gun.global_transform * local)


func _release() -> void:
	_lock = false
	if _phase == Phase.LOCKED or _phase == Phase.SETTLE:
		_begin_forward(weapon.stats.slide_release_time)
		set_physics_process(true)


func _resolve() -> bool:
	var gun := weapon.holder.gun
	if not gun.is_inside_tree():
		return false

	if gun == _gun:
		return true

	_gun = gun
	_scale = maxf(gun.scale.x, 0.0001)

	var stats := weapon.stats
	_slide.clear()
	_barrel.clear()
	for n in stats.slide_parts:
		_slide.append(_part(gun, n))

	for n in stats.barrel_parts:
		_barrel.append(_part(gun, n))

	_trigger = _part(gun, stats.trigger_part)
	_stop = _part(gun, stats.catch_part)
	_handle = _part(gun, stats.handle_part) if stats.handle_part else null
	_cover = _part(gun, stats.cover_part) if stats.cover_part else null
	_selector = _part(gun, stats.selector_part) if stats.selector_part else null
	_cover_t = -1.0
	_pivot = _in_gun(weapon.holder.barrel_pivot).origin
	_port = _in_gun(weapon.holder.ejector)

	if is_instance_valid(_round):
		_round.queue_free()

	var cartridge := gun.get_node(NodePath(stats.feed_part)) as Node3D
	_resolve_feed(cartridge)
	_round = cartridge.duplicate() as Node3D
	_round.visible = false
	gun.add_child(_round)

	_s = 0.0
	_h = 0.0
	_lever = 0.0
	_pull = 0.0
	_sel = 1.0 if weapon.automatic else 0.0
	_sel_t = -1.0
	_reach = 0.0
	_phase = Phase.IDLE
	if weapon.ammo <= 0 and weapon.stats.slide_lock:
		_s = weapon.stats.slide_lock_hold
		_lever = 1.0
		_phase = Phase.LOCKED

	_apply()
	return true


func _part(gun: Node3D, part_name: StringName) -> Part:
	var p := Part.new()
	p.node = gun.get_node(NodePath(part_name)) as Node3D
	p.rest = p.node.transform
	return p


func _resolve_feed(cartridge: Node3D) -> void:
	var bounds := AABB()
	var first := true
	for child in cartridge.get_children():
		var mesh := child as MeshInstance3D
		var box := mesh.transform * mesh.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false

	_feed_half = bounds.size.y * 0.5
	_feed_center = bounds.get_center()

	var start := _in_gun(weapon.holder.feed_start)
	var end := _in_gun(weapon.holder.feed_end)
	_feed_from = start.origin
	_feed_to = end.origin
	_feed_from_angle = atan2(start.basis.x.y, start.basis.x.x)
	_feed_to_angle = atan2(end.basis.x.y, end.basis.x.x)
	_feed_head = _feed_from.x - cos(_feed_from_angle) * _feed_half
	_feed_breech = _feed_to.x - cos(_feed_to_angle) * _feed_half


func _in_gun(node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != _gun:
		if n is Node3D:
			t = (n as Node3D).transform * t

		n = n.get_parent()

	return t


func _begin_forward(time: float) -> void:
	_feeding = _cycle_feed if _manual else weapon.ammo > 0 or _feed_forced
	_phase = Phase.FORWARD
	_t = 0.0
	_from = _s
	_duration = maxf(time * _from, 0.006)


func _step_slide(delta: float) -> void:
	var stats := weapon.stats

	match _phase:
		Phase.BACK:
			_t += delta
			var duration := maxf(_back_time * (1.0 - _from), 0.006)
			var u := minf(_t / duration, 1.0)
			_s = lerpf(_from, 1.0, 1.0 - (1.0 - u) * (1.0 - u))
			if not _ejected and _s >= _eject_at:
				_ejected = true
				if _eject_wanted:
					ejected.emit()

			if u >= 1.0:
				if _manual:
					cycled_back.emit()

				if _lock:
					_phase = Phase.SETTLE
					_t = 0.0
					_from = _s
					slide_locked.emit()
				else:
					_begin_forward(_forward_time)

		Phase.SETTLE:
			_t += delta
			var u := minf(_t / lock_settle_time, 1.0)
			_s = lerpf(_from, stats.slide_lock_hold, 1.0 - (1.0 - u) * (1.0 - u))
			if u >= 1.0:
				_phase = Phase.LOCKED

		Phase.FORWARD:
			_t += delta
			var u := minf(_t / _duration, 1.0)
			_s = _from * (1.0 - u * u)
			if u >= 1.0:
				_s = 0.0
				_phase = Phase.BOUNCE
				_t = 0.0
				if _manual:
					cycled_forward.emit()

		Phase.BOUNCE:
			_t += delta
			var u := minf(_t / bounce_time, 1.0)
			_s = bounce_height * sin(PI * u)
			if u >= 1.0:
				_s = 0.0
				_phase = Phase.IDLE
				if _manual:
					cycle_finished.emit()


func _open_cover() -> void:
	if _cover != null and _cover_t < 0.0:
		_cover_t = 0.0


func _step_cover(delta: float) -> void:
	if _cover_t >= 0.0:
		_cover_t = minf(_cover_t + delta, cover_time)


func _step_selector(delta: float) -> void:
	if _sel_t < 0.0:
		return

	_sel_t += delta
	var u := minf(_sel_t / weapon.stats.selector_time, 1.0)

	var swing := clampf((u - selector_reach) / (selector_land - selector_reach), 0.0, 1.0)
	var travel := 1.0 + 2.70158 * pow(swing - 1.0, 3.0) + 1.70158 * pow(swing - 1.0, 2.0)
	_sel = lerpf(_sel_from, _sel_to, travel)

	if u < selector_reach:
		_reach = 1.0 - pow(1.0 - u / selector_reach, 2.0)
	elif u < selector_land:
		_reach = 1.0
	else:
		_reach = 1.0 - smoothstep(0.0, 1.0, (u - selector_land) / (1.0 - selector_land))

	if not _sel_hit and travel >= 1.0:
		_sel_hit = true
		selector_clicked.emit()

	if u >= 1.0:
		_sel = _sel_to
		_sel_t = -1.0
		_reach = 0.0


func _step_controls(delta: float) -> void:
	var lever_target := 0.0
	if (
		_phase == Phase.SETTLE or _phase == Phase.LOCKED
		or (_phase == Phase.BACK and _lock and _s > 0.8)
	):
		lever_target = 1.0

	_lever = lerpf(_lever, lever_target, 1.0 - exp(-lever_speed * delta))

	_hold = maxf(_hold - delta, 0.0)
	var pulled := _hold > 0.0
	if not weapon.stats.manual_cycle:
		pulled = pulled or Input.is_action_pressed(weapon.fire_action)

	var speed := trigger_pull_speed if pulled else trigger_release_speed
	_pull = lerpf(_pull, 1.0 if pulled else 0.0, 1.0 - exp(-speed * delta))


func _apply() -> void:
	var stats := weapon.stats

	var travel := stats.slide_travel / _scale
	for p in _slide:
		p.node.transform = Transform3D(
			p.rest.basis,
			p.rest.origin + Vector3(-travel * _s, 0.0, 0.0),
		)

	if _handle != null:
		_handle.node.transform = Transform3D(
			_handle.rest.basis,
			_handle.rest.origin + Vector3(-travel * _h, 0.0, 0.0),
		)

	if _cover != null:
		var u := maxf(_cover_t, 0.0) / cover_time
		var open := 1.0 + 2.70158 * pow(u - 1.0, 3.0) + 1.70158 * pow(u - 1.0, 2.0)
		var shut := Basis(Vector3.RIGHT, -deg_to_rad(stats.cover_degrees) * (1.0 - open))
		_cover.node.transform = Transform3D(shut * _cover.rest.basis, _cover.rest.origin)

	var back := smoothstep(0.0, barrel_follow, _s)
	var tilt := deg_to_rad(stats.barrel_tilt_degrees) * smoothstep(barrel_follow * 0.8, 0.4, _s)
	var rot := Basis(Vector3.BACK, tilt)
	var shift := Vector3(-stats.barrel_travel / _scale * back, 0.0, 0.0)
	var barrel := Transform3D(rot, _pivot - rot * _pivot + shift)
	for p in _barrel:
		p.node.transform = barrel * p.rest

	var stop_angle := -deg_to_rad(stats.slide_stop_degrees) * _lever
	_stop.node.transform = _stop.rest * Transform3D(Basis(Vector3.BACK, stop_angle), Vector3.ZERO)

	var trigger_angle := -deg_to_rad(stats.trigger_pull_degrees) * _pull
	_trigger.node.transform = _trigger.rest * Transform3D(
		Basis(Vector3.BACK, trigger_angle),
		Vector3.ZERO,
	)

	weapon.holder.pull_trigger(_pull)

	if _selector != null:
		var angle := deg_to_rad(stats.selector_degrees) * _sel
		_selector.node.transform = Transform3D(
			Basis(Vector3.BACK, angle) * _selector.rest.basis,
			_selector.rest.origin,
		)
		weapon.holder.operate_selector(_in_gun(weapon.holder.selector_pad).origin * _scale, _reach)

	if stats.manual_cycle:
		weapon.holder.follow_pump(stats.slide_travel * _s)

	_apply_round(travel)


func _apply_round(travel: float) -> void:
	var show := _feeding and _phase == Phase.FORWARD
	var fresh := show and not _round.visible
	_round.visible = show
	if not show:
		return

	var head := maxf(_feed_breech - travel * _s, _feed_head)
	var span := _feed_breech - _feed_head
	var along := clampf((head - _feed_head) / span, 0.0, 1.0)
	var rise := smoothstep(0.05, 0.85, along)
	var angle := lerpf(_feed_from_angle, _feed_to_angle, rise)

	var center := Vector3(
		head + cos(angle) * _feed_half,
		lerpf(_feed_from.y, _feed_to.y, rise),
		lerpf(_feed_from.z, _feed_to.z, rise),
	)
	var basis := Basis(Vector3.BACK, angle - PI * 0.5)
	_round.transform = Transform3D(basis, center - basis * _feed_center)
	if fresh:
		_round.reset_physics_interpolation()


func _settled() -> bool:
	if _phase != Phase.IDLE and _phase != Phase.LOCKED:
		return false

	if _cover_t >= 0.0 and _cover_t < cover_time:
		return false

	var squeezed := Input.is_action_pressed(weapon.fire_action)
	if _hold > 0.0 or (squeezed and not weapon.stats.manual_cycle):
		return false

	if _sel_t >= 0.0:
		return false

	var lever_goal := 1.0 if _phase == Phase.LOCKED else 0.0
	return absf(_lever - lever_goal) < 0.002 and _pull < 0.002
