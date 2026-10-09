class_name WeaponReload
extends Node

enum Kind {
	GRIP,
	STAGE,
	POUCH,
	RACK,
}

enum Cue {
	RELEASE,
	PULL,
	STOW,
	GRAB,
	SEAT,
	DROP,
	TAKE_SLIDE,
	LET_GO,
}


class MagShape:
	var frame := Transform3D.IDENTITY
	var length := 0.0
	var width := 0.0
	var depth := 0.0


class Step:
	var kind := Kind.GRIP
	var amount := 0.0
	var slot := 0.0
	var weight := 1.0
	var tilt := 0.0
	var align := 0.0
	var accelerate := false
	var bulge := Vector3.ZERO


class Anchor:
	var bone := 0
	var at := Vector3.ZERO


class Beat:
	var key := 0
	var offset := 0.0
	var at := 0.0
	var cue := Cue.SEAT


@export_group("Parts")
@export var mag_part: StringName = &"EmptyMag"
@export var spare_part: StringName = &"MagFull"

@export_group("Gun")
@export var tilt_degrees := 25.0
@export var gun_pull := 0.06
@export var seat_jolt_degrees := 3.0

@export_group("Belt pouch")
@export var pouch_marker: StringName = &"BeltPouch"
@export var stow_marker: StringName = &"BeltStow"
@export var pouch_pitch_degrees := 30.0
@export var pouch_lift := 0.06

@export_group("Magazine")
@export var stage_distance := 0.12
@export var hold_along := 0.045
@export var reach_bulge := Vector3(0.0, 0.0, -0.06)
@export var carry_bulge := Vector3(0.0, 0.0, 0.05)

@export_group("Slide rack")
@export var rack_pull := 0.022
@export_range(-90.0, 90.0) var rack_yaw_degrees := 20.0
@export_range(-90.0, 90.0) var rack_roll_degrees := 15.0

@export_group("Dropped magazine")
@export var drop_speed := 1.4
@export var drop_lifetime := 6.0
@export var max_dropped := 4
@export_flags_3d_physics var drop_layer := 4
@export_flags_3d_physics var drop_mask := 1

var weapon: Weapon

var active := false
var tilt := 0.0
var pull := 0.0
var support_weight := 0.0

var _gun: Node3D
var _scale := 1.0
var _mag: Node3D
var _mag_shape: MagShape
var _spare_shape: MagShape
var _seated := Transform3D.IDENTITY
var _grip_rel := Transform3D.IDENTITY
var _in_hand := Transform3D.IDENTITY
var _rack := Transform3D.IDENTITY
var _rack_inset := 0.0
var _take_anchor: Anchor
var _stow_anchor: Anchor
var _view: Node3D

var _t := 0.0
var _duration := 1.6
var _dropped: Array[RigidBody3D] = []

var _keys: Array[Step] = []
var _beats: Array[Beat] = []
var _starts := PackedFloat32Array()
var _ends := PackedFloat32Array()
var _next := 0
var _start_key := Step.new()

var _tactical := false
var _driving := false
var _slide_from := 0.0
var _jolt := 0.0


func _ready() -> void:
	set_physics_process(false)
	set_process(false)

	weapon = get_parent() as Weapon
	weapon.reload_started.connect(_on_started)
	weapon.reload_finished.connect(_finish)
	weapon.holder.spine.reload = self


func _on_started() -> void:
	_resolve()

	_duration = maxf(weapon.stats.reload_time, 0.2)
	_t = 0.0
	_tactical = weapon.ammo > 0
	_driving = false
	_jolt = 0.0

	_build()

	active = true
	set_physics_process(true)
	set_process(true)


func _physics_process(delta: float) -> void:
	if not weapon.is_reloading():
		_finish()
		return

	_t += delta
	var p := _progress()
	var at := _locate(p)
	var k1 := _keys[int(at.x)]
	var k0 := _previous(int(at.x))
	var e := _shape(k1, at.y)

	_jolt = move_toward(_jolt, 0.0, delta * 12.0)
	var level := lerpf(k0.tilt, k1.tilt, e)
	tilt = deg_to_rad(tilt_degrees) * level + deg_to_rad(seat_jolt_degrees) * _jolt
	pull = gun_pull * level
	support_weight = smoothstep(0.0, 0.03, p) * (1.0 - smoothstep(0.97, 1.0, p))

	while _next < _beats.size() and p >= _beats[_next].at:
		_fire(_beats[_next].cue)
		_next += 1

	if _driving:
		weapon.animator.drive_slide(
			_slide_from + _rack_amount(k0, k1, e) / maxf(weapon.stats.slide_travel, 0.0001)
		)

	if p >= 1.0:
		_finish()


func _process(_delta: float) -> void:
	if not _view.visible:
		return

	var p := _visual_progress()
	var at := _locate(p)
	var k1 := _keys[int(at.x)]
	var k0 := _previous(int(at.x))
	var e := _shape(k1, at.y)

	var gun_xf := _gun.get_global_transform_interpolated()
	var gun_rigid := Transform3D(gun_xf.basis.orthonormalized(), gun_xf.origin)

	var hand := weapon.holder.support_hand
	var hand_frame := hand.get_global_transform_interpolated() * hand.body_offset.affine_inverse()
	var held := Transform3D(hand_frame.basis.orthonormalized(), hand_frame.origin) * _in_hand

	var gap := lerpf(_gap(k0), _gap(k1), e)
	var aligned := gun_rigid * _seated * Transform3D(Basis.IDENTITY, Vector3(0.0, -gap, 0.0))

	var ramp := smoothstep(0.4, 1.0, at.y) if k1.align > k0.align else smoothstep(0.0, 0.6, at.y)
	var weight := lerpf(k0.align, k1.align, ramp)
	_view.global_transform = _mix(held, aligned, weight)


func support_pose(gun_pose: Transform3D, skel: Skeleton3D) -> Transform3D:
	var at := _locate(_progress())
	var k1 := _keys[int(at.x)]
	var k0 := _previous(int(at.x))
	var e := _shape(k1, at.y)

	var from := _key_frame(k0, gun_pose, skel)
	var to := _key_frame(k1, gun_pose, skel)

	return _mix(from, to, e, k1.bulge)


func _key_frame(key: Step, gun_pose: Transform3D, skel: Skeleton3D) -> Transform3D:
	var inverse := _in_hand.affine_inverse()

	match key.kind:
		Kind.STAGE:
			var offset := Transform3D(Basis.IDENTITY, Vector3(0.0, -key.amount, 0.0))
			return gun_pose * _seated * offset * inverse

		Kind.POUCH:
			var mag := _pouch_frame(skel, key.slot)
			return Transform3D(mag.basis, mag.origin + Vector3.UP * key.amount) * inverse

		Kind.RACK:
			var offset := Transform3D(Basis.IDENTITY, Vector3(-key.amount, 0.0, 0.0))
			return gun_pose * offset * _rack_frame() * _grip_rel.affine_inverse()

	return gun_pose * weapon.holder.spine.hold_support


func _pouch_frame(skel: Skeleton3D, slot: float) -> Transform3D:
	var pitch := deg_to_rad(pouch_pitch_degrees)
	var aim := Vector3(0.0, sin(pitch), cos(pitch))
	var up := Vector3(0.0, cos(pitch), -sin(pitch))
	var basis := Basis(aim, up, aim.cross(up)) * _seated.basis

	var hand := _anchor_point(_take_anchor, skel).lerp(_anchor_point(_stow_anchor, skel), slot)
	return Transform3D(basis, hand - basis.y * hold_along)


func _anchor_point(anchor: Anchor, skel: Skeleton3D) -> Vector3:
	return skel.get_bone_global_pose(anchor.bone) * anchor.at


func _anchor_of(marker_name: StringName) -> Anchor:
	var marker := weapon.player.find_child(String(marker_name), true, false) as Node3D
	var attachment := marker.get_parent() as BoneAttachment3D

	var anchor := Anchor.new()
	anchor.bone = (attachment.get_parent() as Skeleton3D).find_bone(attachment.bone_name)
	anchor.at = marker.position
	return anchor


func _gap(key: Step) -> float:
	return key.amount if key.kind == Kind.STAGE else stage_distance


func _rack_amount(k0: Step, k1: Step, e: float) -> float:
	if k1.kind != Kind.RACK:
		return 0.0

	var from := k0.amount if k0.kind == Kind.RACK else 0.0
	return lerpf(from, k1.amount, e)


func _add(
	kind: Kind,
	amount: float,
	weight: float,
	level: float,
	align: float,
	accelerate := false,
	bulge := Vector3.ZERO,
	slot := 0.0,
) -> int:
	var key := Step.new()
	key.kind = kind
	key.amount = amount
	key.weight = weight
	key.tilt = level
	key.align = align
	key.accelerate = accelerate
	key.bulge = bulge
	key.slot = slot
	_keys.append(key)
	return _keys.size() - 1


func _cue(cue: Cue, key: int, offset: float) -> void:
	var beat := Beat.new()
	beat.key = key
	beat.offset = offset
	beat.cue = cue
	_beats.append(beat)


func _build() -> void:
	_keys.clear()
	_beats.clear()
	_next = 0

	if _tactical:
		var first := _add(Kind.STAGE, 0.0, 0.7, 0.5, 1.0)
		var out := _add(Kind.STAGE, stage_distance, 1.4, 1.0, 1.0)
		_add(Kind.POUCH, pouch_lift, 2.2, 1.0, 0.0, false, reach_bulge, 1.0)
		var stow := _add(Kind.POUCH, 0.0, 0.9, 1.0, 0.0, false, Vector3.ZERO, 1.0)
		_add(Kind.POUCH, 0.0, 1.4, 1.0, 0.0, false, Vector3(0.0, 0.03, 0.0), 0.0)
		var take := _add(Kind.POUCH, pouch_lift, 1.0, 1.0, 0.0, false, Vector3.ZERO, 0.0)
		_add(Kind.STAGE, stage_distance, 2.6, 1.0, 1.0, false, carry_bulge)
		var seat := _add(Kind.STAGE, 0.0, 1.1, 1.0, 1.0, true)
		_add(Kind.GRIP, 0.0, 1.7, 0.0, 0.0)

		_cue(Cue.RELEASE, first, 1.0)
		_cue(Cue.PULL, out, 0.0)
		_cue(Cue.STOW, stow, 1.0)
		_cue(Cue.GRAB, take, 0.0)
		_cue(Cue.SEAT, seat, 1.0)
	else:
		var first := _add(Kind.POUCH, 0.0, 2.5, 1.0, 0.0, false, reach_bulge, 0.0)
		var take := _add(Kind.POUCH, pouch_lift, 1.2, 1.0, 0.0)
		_add(Kind.STAGE, stage_distance, 3.0, 1.0, 1.0, false, carry_bulge)
		var seat := _add(Kind.STAGE, 0.0, 1.2, 1.0, 1.0, true)
		var grab := _add(Kind.RACK, 0.0, 1.6, 0.4, 0.0)
		var back := _add(Kind.RACK, rack_pull, 1.4, 0.4, 0.0)
		_add(Kind.GRIP, 0.0, 3.0, 0.0, 0.0)

		_cue(Cue.DROP, first, 0.15)
		_cue(Cue.GRAB, take, 0.0)
		_cue(Cue.SEAT, seat, 1.0)
		_cue(Cue.TAKE_SLIDE, grab, 1.0)
		_cue(Cue.LET_GO, back, 1.0)

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


func _fire(cue: Cue) -> void:
	match cue:
		Cue.RELEASE:
			_jolt = 0.4

		Cue.PULL:
			_mag.visible = false
			_show_view()

		Cue.STOW:
			_view.visible = false

		Cue.GRAB:
			_show_view()

		Cue.SEAT:
			_view.visible = false
			_mag.visible = true
			_jolt = 1.0

		Cue.DROP:
			_drop()

		Cue.TAKE_SLIDE:
			_slide_from = weapon.animator.slide_position()
			_driving = true
			weapon.animator.drive_slide(_slide_from)

		Cue.LET_GO:
			_driving = false
			weapon.animator.release_slide()


func _show_view() -> void:
	_view.visible = true
	_view.reset_physics_interpolation()


func _previous(index: int) -> Step:
	return _keys[index - 1] if index > 0 else _start_key


func _locate(p: float) -> Vector2:
	var i := 0
	while i < _keys.size() - 1 and p >= _ends[i]:
		i += 1

	var span := maxf(_ends[i] - _starts[i], 0.0001)
	return Vector2(float(i), clampf((p - _starts[i]) / span, 0.0, 1.0))


func _shape(key: Step, u: float) -> float:
	return u * u if key.accelerate else smoothstep(0.0, 1.0, u)


func _mix(a: Transform3D, b: Transform3D, u: float, bulge := Vector3.ZERO) -> Transform3D:
	var origin := a.origin.lerp(b.origin, u) + bulge * sin(PI * u)
	var basis := a.basis.orthonormalized().slerp(b.basis.orthonormalized(), u)
	return Transform3D(basis, origin)


func _progress() -> float:
	return clampf(_t / _duration, 0.0, 1.0)


func _visual_progress() -> float:
	var ahead := Engine.get_physics_interpolation_fraction() / float(
		Engine.physics_ticks_per_second
	)
	return clampf((_t + ahead) / _duration, 0.0, 1.0)


func _finish() -> void:
	if not active:
		return

	active = false
	tilt = 0.0
	pull = 0.0
	support_weight = 0.0

	if _driving:
		_driving = false
		weapon.animator.release_slide()

	_view.visible = false
	_mag.visible = true

	set_physics_process(false)
	set_process(false)


func _drop() -> void:
	var local := _mag.transform * _mag_shape.frame
	var world := _gun.global_transform * Transform3D(local.basis, local.origin)
	var frame := Transform3D(world.basis.orthonormalized(), world.origin)

	_mag.visible = false

	var body := RigidBody3D.new()
	body.top_level = true
	body.collision_layer = drop_layer
	body.collision_mask = drop_mask
	body.mass = 0.25
	body.continuous_cd = true
	body.axis_lock_linear_z = true
	body.axis_lock_angular_x = true
	body.axis_lock_angular_y = true
	body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM

	var length := _mag_shape.length * _scale
	body.center_of_mass = Vector3(0.0, length * 0.5, 0.0)

	var surface := PhysicsMaterial.new()
	surface.bounce = 0.25
	surface.friction = 0.7
	body.physics_material_override = surface

	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(_mag_shape.width, _mag_shape.length, _mag_shape.depth) * _scale
	collider.shape = box
	collider.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, length * 0.5, 0.0))
	body.add_child(collider)

	body.add_child(_visual(_mag, _mag_shape))
	add_child(body)
	body.global_transform = frame
	body.reset_physics_interpolation()

	var velocity := weapon.player.velocity
	var inherited := Vector3(velocity.x, velocity.y, 0.0)
	body.linear_velocity = -frame.basis.y * drop_speed + inherited
	body.angular_velocity = Vector3(0.0, 0.0, randf_range(-3.0, 3.0))

	_dropped.append(body)
	while _dropped.size() > max_dropped:
		var old: RigidBody3D = _dropped.pop_front()
		if is_instance_valid(old):
			old.queue_free()

	get_tree().create_timer(drop_lifetime).timeout.connect(
		func() -> void:
			if is_instance_valid(body):
				_dropped.erase(body)
				body.queue_free(),
	)


func _visual(source: Node3D, shape: MagShape) -> Node3D:
	var copy := source.duplicate() as Node3D
	copy.visible = true
	copy.transform = Transform3D(Basis.from_scale(Vector3.ONE * _scale), Vector3.ZERO) * shape \
			.frame \
			.affine_inverse()
	return copy


func _resolve() -> void:
	var holder := weapon.holder
	if holder.gun == _gun:
		return

	_gun = holder.gun
	_scale = maxf(_gun.scale.x, 0.0001)

	_mag = _gun.get_node(NodePath(mag_part)) as Node3D
	var spare := _gun.get_node(NodePath(spare_part)) as Node3D
	_mag_shape = _shape_of(_mag)
	_spare_shape = _shape_of(spare)

	var seated := _mag.transform * _mag_shape.frame
	_seated = Transform3D(seated.basis.orthonormalized(), seated.origin * _scale)

	var grip := holder.support_grip
	_grip_rel = holder.spine.hold_support.affine_inverse() * Transform3D(
		grip.frame.orthonormalized(),
		grip.hole,
	)
	_in_hand = _grip_rel * Transform3D(Basis.IDENTITY, Vector3(0.0, -hold_along, 0.0))

	_resolve_rack()
	_take_anchor = _anchor_of(pouch_marker)
	_stow_anchor = _anchor_of(stow_marker)

	if is_instance_valid(_view):
		_view.queue_free()

	_view = Node3D.new()
	_view.top_level = true
	_view.visible = false
	_view.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_view.add_child(_visual(spare, _spare_shape))
	add_child(_view)


func _resolve_rack() -> void:
	var slide := weapon.animator.slide_node()
	var points := PackedVector3Array()
	_gather(slide, slide, points)

	var low := INF
	var high := -INF
	for point in points:
		low = minf(low, point.z)
		high = maxf(high, point.z)

	var half := (high - low) * 0.5 * _scale
	_rack_inset = weapon.holder.support_grip.depth * 0.5 + weapon.holder.finger_radius * 0.4 - half

	var frame := _rest_in_gun(weapon.holder.rack_grab)
	_rack = Transform3D(frame.basis.orthonormalized(), frame.origin * _scale)


func _rest_in_gun(marker: Node3D) -> Transform3D:
	var slide := weapon.animator.slide_node()
	var t := Transform3D.IDENTITY
	var n: Node = marker
	while n != _gun:
		if n is Node3D:
			var local := weapon.animator.slide_rest() if n == slide else (n as Node3D).transform
			t = local * t

		n = n.get_parent()

	return t


func _rack_frame() -> Transform3D:
	var side := weapon.holder.support_grip.side
	var across := Vector3.BACK
	var along := Vector3.RIGHT * -side
	var hand := Basis(along, across, along.cross(across))

	var turn := Basis(Vector3.UP, deg_to_rad(rack_yaw_degrees)) * Basis(
		Vector3.RIGHT,
		deg_to_rad(rack_roll_degrees),
	)
	hand = _rack.basis * turn * hand

	return Transform3D(hand * _grip_rel.basis, _rack.origin - hand.y * _rack_inset)


func _shape_of(node: Node3D) -> MagShape:
	var points := PackedVector3Array()
	_gather(node, node, points)

	var mean := Vector2.ZERO
	for point in points:
		mean += Vector2(point.x, point.y)

	mean /= float(points.size())

	var xx := 0.0
	var yy := 0.0
	var xy := 0.0
	for point in points:
		var d := Vector2(point.x, point.y) - mean
		xx += d.x * d.x
		yy += d.y * d.y
		xy += d.x * d.y

	var angle := 0.5 * atan2(2.0 * xy, xx - yy)
	var axis := Vector2(cos(angle), sin(angle))
	if axis.y < 0.0:
		axis = -axis

	var across := Vector2(axis.y, -axis.x)

	var along_min := INF
	var along_max := -INF
	var across_min := INF
	var across_max := -INF
	var depth_min := INF
	var depth_max := -INF
	for point in points:
		var q := Vector2(point.x, point.y)
		along_min = minf(along_min, q.dot(axis))
		along_max = maxf(along_max, q.dot(axis))
		across_min = minf(across_min, q.dot(across))
		across_max = maxf(across_max, q.dot(across))
		depth_min = minf(depth_min, point.z)
		depth_max = maxf(depth_max, point.z)

	var base := axis * along_min + across * (across_min + across_max) * 0.5

	var shape := MagShape.new()
	shape.frame = Transform3D(
		Basis(Vector3(across.x, across.y, 0.0), Vector3(axis.x, axis.y, 0.0), Vector3.BACK),
		Vector3(base.x, base.y, (depth_min + depth_max) * 0.5),
	)
	shape.length = along_max - along_min
	shape.width = across_max - across_min
	shape.depth = depth_max - depth_min
	return shape


func _gather(node: Node, root: Node3D, points: PackedVector3Array) -> void:
	for child in node.get_children():
		var mesh := child as MeshInstance3D
		if mesh != null and mesh.mesh != null:
			var xf := _relative(mesh, root)
			for s in mesh.mesh.get_surface_count():
				var arrays := mesh.mesh.surface_get_arrays(s)
				for v in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
					points.append(xf * v)

		_gather(child, root, points)


func _relative(node: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t

		n = n.get_parent()

	return t
