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

@export_group("Parts")
@export var slide_parts: Array[StringName] = [&"Slide", &"Cover"]
@export var barrel_parts: Array[StringName] = [&"Barrel", &"MuzzleNut"]
@export var trigger_part: StringName = &"Trigger"
@export var slide_stop_part: StringName = &"SlideStop"

@export_group("Ejection")
@export_range(0.05, 0.9) var eject_at := 0.35

@export_group("Feed")
@export var feed_part: StringName = &"Bullet"

@export_group("Feel")
@export var lock_settle_time := 0.04
@export var bounce_height := 0.05
@export var bounce_time := 0.04

@export_range(0.05, 0.5) var barrel_follow := 0.16

@export var lever_speed := 45.0
@export var trigger_pull_speed := 70.0
@export var trigger_release_speed := 22.0
@export var trigger_hold := 0.09

var weapon: Weapon

var _gun: Node3D
var _scale := 1.0

var _slide: Array[Part] = []
var _barrel: Array[Part] = []
var _trigger: Part
var _stop: Part
var _pivot := Vector3.ZERO
var _pad_local := Vector3.ZERO
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

var _phase := Phase.IDLE
var _lock := false
var _t := 0.0
var _from := 0.0
var _duration := 0.05

var _s := 0.0
var _lever := 0.0
var _pull := 0.0
var _hold := 0.0


func _ready() -> void:
	weapon = get_parent() as Weapon
	weapon.fired.connect(_on_fired)
	weapon.dry_fired.connect(_on_dry_fired)
	weapon.ammo_changed.connect(_on_ammo_changed)
	weapon.reload_finished.connect(_on_reload_finished)


func _physics_process(delta: float) -> void:
	if not _resolve():
		return

	_step_slide(delta)
	_step_controls(delta)
	_apply()

	if _settled():
		set_physics_process(false)


func _on_fired(_muzzle: Transform3D) -> void:
	_resolve()

	_hold = trigger_hold
	_lock = weapon.ammo <= 0 and weapon.stats.slide_lock
	_ejected = false
	_feed_forced = false

	_phase = Phase.BACK
	_t = 0.0
	_from = _s
	set_physics_process(true)


func _on_dry_fired() -> void:
	_hold = trigger_hold
	set_physics_process(true)


func _on_ammo_changed(current: int, _capacity: int) -> void:
	if current > 0:
		_release()


func _on_reload_finished() -> void:
	_release()


func release_slide() -> void:
	_feed_forced = true
	_lock = false
	if _phase == Phase.LOCKED or _phase == Phase.SETTLE or _phase == Phase.DRIVEN:
		_begin_forward(weapon.stats.slide_release_time)
		set_physics_process(true)


func drive_slide(value: float) -> void:
	_lock = false
	_phase = Phase.DRIVEN
	_s = value
	set_physics_process(true)


func slide_position() -> float:
	return _s


func slide_node() -> Node3D:
	_resolve()
	return _slide[0].node


func slide_rest() -> Transform3D:
	return _slide[0].rest


func port_transform() -> Transform3D:
	var travel := weapon.stats.slide_travel / _scale
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

	_slide.clear()
	_barrel.clear()
	for n in slide_parts:
		_slide.append(_part(gun, n))

	for n in barrel_parts:
		_barrel.append(_part(gun, n))

	_trigger = _part(gun, trigger_part)
	_stop = _part(gun, slide_stop_part)
	_pivot = _in_gun(weapon.holder.barrel_pivot).origin
	_pad_local = _trigger.rest.affine_inverse() * _in_gun(weapon.holder.trigger_pad).origin
	_port = _in_gun(weapon.holder.ejector)

	if is_instance_valid(_round):
		_round.queue_free()

	var cartridge := gun.get_node(NodePath(feed_part)) as Node3D
	_resolve_feed(cartridge)
	_round = cartridge.duplicate() as Node3D
	_round.visible = false
	gun.add_child(_round)

	_s = 0.0
	_lever = 0.0
	_pull = 0.0
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
	_feeding = weapon.ammo > 0 or _feed_forced
	_phase = Phase.FORWARD
	_t = 0.0
	_from = _s
	_duration = maxf(time * _from, 0.006)


func _step_slide(delta: float) -> void:
	var stats := weapon.stats

	match _phase:
		Phase.BACK:
			_t += delta
			var duration := maxf(stats.slide_back_time * (1.0 - _from), 0.006)
			var u := minf(_t / duration, 1.0)
			_s = lerpf(_from, 1.0, 1.0 - (1.0 - u) * (1.0 - u))
			if not _ejected and _s >= eject_at:
				_ejected = true
				ejected.emit()

			if u >= 1.0:
				if _lock:
					_phase = Phase.SETTLE
					_t = 0.0
					_from = _s
				else:
					_begin_forward(stats.slide_forward_time)

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

		Phase.BOUNCE:
			_t += delta
			var u := minf(_t / bounce_time, 1.0)
			_s = bounce_height * sin(PI * u)
			if u >= 1.0:
				_s = 0.0
				_phase = Phase.IDLE


func _step_controls(delta: float) -> void:
	var lever_target := 0.0
	if (
		_phase == Phase.SETTLE or _phase == Phase.LOCKED
		or (_phase == Phase.BACK and _lock and _s > 0.8)
	):
		lever_target = 1.0

	_lever = lerpf(_lever, lever_target, 1.0 - exp(-lever_speed * delta))

	_hold = maxf(_hold - delta, 0.0)
	var pulled := _hold > 0.0 or Input.is_action_pressed(weapon.fire_action)
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

	if weapon.holder.has_trigger_finger():
		weapon.holder.pose_trigger_finger(_trigger.node.transform * _pad_local * _scale)

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

	if _hold > 0.0 or Input.is_action_pressed(weapon.fire_action):
		return false

	var lever_goal := 1.0 if _phase == Phase.LOCKED else 0.0
	return absf(_lever - lever_goal) < 0.002 and _pull < 0.002
