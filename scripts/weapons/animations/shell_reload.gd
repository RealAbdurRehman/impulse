class_name ShellReload
extends WeaponReload

const SHELL_WEIGHT := 7.8

@export_group("Shell")
@export var shell_hold_along := 0.015

var _release := -1.0
var _from_tilt := 0.0
var _from_pull := 0.0
var _from_lowered := 0.0
var _from_weight := 0.0


func _on_started() -> void:
	_release = -1.0
	_resolve()

	_duration = maxf(weapon.reload_total, 0.2)
	_t = 0.0
	_tactical = false
	_driving = false
	_jolt = 0.0

	_build()

	active = true
	set_physics_process(true)
	set_process(true)


func _physics_process(delta: float) -> void:
	if _release < 0.0:
		super(delta)
		return

	_release += delta
	var left := 1.0 - smoothstep(0.0, 1.0, _release / weapon.stats.shell_release_time)
	tilt = _from_tilt * left
	pull = _from_pull * left
	lowered = _from_lowered * left
	support_weight = _from_weight * left

	if left <= 0.0:
		_end()


func _shape(key: Step, u: float) -> float:
	var eased := smoothstep(0.0, 1.0, u)
	return eased if key.accelerate else lerpf(u, eased, 0.5)


func _fire(cue: Cue) -> void:
	cued.emit(cue)

	match cue:
		Cue.GRAB:
			_show_view()

		Cue.SEAT:
			_view.visible = false
			_jolt = 0.6


func _finish() -> void:
	if not active or _release >= 0.0:
		return

	if _progress() < 0.97 and weapon.stats.shell_release_time > 0.0:
		_release = 0.0
		_from_tilt = tilt
		_from_pull = pull
		_from_lowered = lowered
		_from_weight = support_weight
		_view.visible = false
		return

	_end()


func _end() -> void:
	_release = -1.0
	active = false
	lowered = 0.0
	tilt = 0.0
	pull = 0.0
	support_weight = 0.0
	rack_amount = 0.0

	_view.visible = false

	set_physics_process(false)
	set_process(false)


func _build() -> void:
	_keys.clear()
	_beats.clear()
	_next = 0

	for i in weapon.reload_shells:
		_add(Kind.POUCH, 0.0, 3.0, 1.0, 0.0, false, reach_bulge, 0.0)
		var take := _add(Kind.POUCH, pouch_lift, 0.8, 1.0, 0.0)
		_add(Kind.STAGE, stage_distance, 2.2, 1.0, 0.0, false, carry_bulge)
		var seat := _add(Kind.STAGE, 0.0, 1.8, 1.0, 1.0, true)

		_cue(Cue.GRAB, take, 0.0)
		_cue(Cue.SEAT, seat, 1.0)

	var back := SHELL_WEIGHT * weapon.stats.shell_return_time / weapon.stats.shell_time
	_add(Kind.GRIP, 0.0, back, 0.0, 0.0)

	var total := 0.0
	for key in _keys:
		total += key.weight

	_starts.resize(_keys.size())
	_ends.resize(_keys.size())
	var run := 0.0
	for i in _keys.size():
		_starts[i] = run / total
		run += _keys[i].weight
		_ends[i] = run / total

	for beat in _beats:
		beat.at = lerpf(_starts[beat.key], _ends[beat.key], beat.offset)

	_beats.sort_custom(
		func(a: Beat, b: Beat) -> bool:
			return a.at < b.at,
	)


func _resolve() -> void:
	var holder := weapon.holder
	if holder.gun == _gun:
		return

	_gun = holder.gun
	_scale = maxf(_gun.scale.x, 0.0001)
	hold_along = shell_hold_along

	var shell := _gun.get_node(NodePath(weapon.stats.spare_mag_part)) as Node3D
	_spare_shape = _shape_of(shell)

	var port := GripFit.local(holder.shell_port, _gun)
	var nose := Vector2(port.basis.x.x, port.basis.x.y).normalized()
	var across := Vector2(nose.y, -nose.x)
	_seated = Transform3D(
		Basis(Vector3(across.x, across.y, 0.0), Vector3(nose.x, nose.y, 0.0), Vector3.BACK),
		port.origin * _scale,
	)

	var grip := holder.support_grip
	var bone := holder.spine.hold_support
	_grip_rel = bone.affine_inverse() * Transform3D(grip.frame.orthonormalized(), grip.hole)
	_in_hand = _grip_rel * Transform3D(Basis.IDENTITY, Vector3(0.0, -hold_along, 0.0))

	_take_anchor = _anchor_of(pouch_marker)
	_stow_anchor = _anchor_of(stow_marker)

	if is_instance_valid(_view):
		_view.queue_free()

	_view = Node3D.new()
	_view.top_level = true
	_view.visible = false
	_view.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_view.add_child(_visual(shell, _spare_shape))
	add_child(_view)
