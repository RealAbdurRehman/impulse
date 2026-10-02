extends PhysicalBoneSimulator3D

@export_group("Tracking")
@export var angular_frequency_hz := 6.5
@export var angular_damping_ratio := 1.15

@export var linear_frequency_hz := 6.0
@export var linear_damping_ratio := 1.15

@export var foot_linear_frequency_hz := 12.0
@export var foot_linear_damping_ratio := 1.0

@export_range(0.0, 1.0) var foot_linear_assist: float = 1.0

@export_group("Leg Strength")
@export var air_tuck_legs := true
@export var legs_ignore_each_other := true

@export var foot_angular_frequency_hz := 18.0
@export var hips_angular_frequency_hz := 10.0

@export var leg_angular_frequency_hz := 12.0
@export var leg_angular_damping_ratio := 1.0

@export var leg_linear_frequency_hz := 12.0
@export var leg_linear_damping_ratio := 1.0

@export var max_leg_track_speed := 5.0

@export_range(0.2, 1.0) var landing_leg_softness := 0.45
@export_range(0.0, 1.0) var leg_linear_assist := 0.6

@export_group("Feedforward")
@export var max_ff_angular_speed := 40.0
@export var feedforward_smoothing_hz := 30.0

@export_range(0.0, 1.0) var feedforward := 1.0

@export_group("Upper Body")
@export var upper_body_stiffness_scale := 10.0

@export_group("Upright")
@export var upright_torque: float = 2800.0
@export var upright_damping: float = 34.0

@export var spine_upright_torque: float = 2600.0
@export var spine_upright_damping: float = 24.0

@export_group("Gravity")
@export_range(0.0, 1.0) var gravity_compensation := 0.0

@export_group("Refs")
@export var player_body: CharacterBody3D
@export var animated_skeleton_path: NodePath

@export var gait: GaitDriver
@export var run_speed: float = 3.2
@export var hips_bone_name: StringName = &"mixamorig7_Hips"

@onready var physics_skeleton: Skeleton3D = get_parent()
@onready var animated_skeleton: Skeleton3D = get_node(animated_skeleton_path)

var hips: PhysicalBone3D

var feet_bones: Array[PhysicalBone3D] = []
var leg_bones: Array[PhysicalBone3D] = []

var thigh_bones: Array[PhysicalBone3D] = []
var shin_bones: Array[PhysicalBone3D] = []

var spine_bones: Array[PhysicalBone3D] = []

var bone_indices: Dictionary = { }
var physical_bones: Array[PhysicalBone3D] = []

var desired_speed := 0.0
var velocity: Vector3 = Vector3.ZERO

var _ang_k := 0.0
var _ang_c := 0.0

var _lin_k := 0.0
var _lin_c := 0.0

var _foot_k := 0.0
var _foot_c := 0.0

var _spine_ang_k := 0.0
var _spine_ang_c := 0.0

var _leg_ang_k := 0.0
var _leg_ang_c := 0.0

var _foot_ang_k := 0.0
var _foot_ang_c := 0.0

var _hips_ang_k := 0.0
var _hips_ang_c := 0.0

var _leg_lin_k := 0.0
var _leg_lin_c := 0.0

var _anim_poses: Array[Transform3D] = []
var _anim_xform := Transform3D.IDENTITY

var _anim_hips_idx := -1
var _anim_upleg_idx: Array[int] = [-1, -1]

var _on_floor := true

var _prev_hips_pos := Vector3.ZERO
var _hips_vel_smooth := Vector3.ZERO

var _ff_prev_q: Dictionary = { }
var _ff_prev_o: Dictionary = { }

var _ff_ang: Dictionary = { }
var _ff_lin: Dictionary = { }


func _ready() -> void:
	_recompute_constants()

	animated_skeleton.skeleton_updated.connect(_on_animated_skeleton_updated)

	_anim_hips_idx = animated_skeleton.find_bone(hips_bone_name)
	for i in animated_skeleton.get_bone_count():
		var bone_n := String(animated_skeleton.get_bone_name(i))

		if bone_n.ends_with("LeftUpLeg"):
			_anim_upleg_idx[0] = i
		elif bone_n.ends_with("RightUpLeg"):
			_anim_upleg_idx[1] = i

	await get_tree().physics_frame

	for child in get_children():
		if child is PhysicalBone3D:
			physical_bones.append(child)

			var idx := animated_skeleton.find_bone(child.bone_name)
			if idx == -1:
				push_warning("No animated bone matches " + child.bone_name)
			else:
				bone_indices[child] = idx

			var bn := String(child.bone_name)
			if bn == String(hips_bone_name):
				hips = child
			elif "Foot" in bn:
				feet_bones.append(child)
			elif "Leg" in bn:
				leg_bones.append(child)

				if "UpLeg" in bn:
					thigh_bones.append(child)
				else:
					shin_bones.append(child)
			elif "Spine" in bn or "Chest" in bn or "Neck" in bn or "Head" in bn:
				spine_bones.append(child)

	for b in physical_bones:
		b.gravity_scale = 1.0 - gravity_compensation

	if legs_ignore_each_other:
		var lefts: Array[PhysicalBone3D] = []
		var rights: Array[PhysicalBone3D] = []
		for group in [leg_bones, feet_bones]:
			for item in group:
				var lb: PhysicalBone3D = item
				var lname := String(lb.bone_name)

				if "Left" in lname:
					lefts.append(lb)
				elif "Right" in lname:
					rights.append(lb)

		for a in lefts:
			for b in rights:
				a.add_collision_exception_with(b)

	await get_tree().process_frame
	for bone in physical_bones:
		if bone_indices.has(bone):
			bone.global_transform = _target_body_transform(bone)

	if hips:
		_prev_hips_pos = hips.global_position

	active = true
	physical_bones_start_simulation()


func _gains(freq_hz: float, ratio: float) -> Vector2:
	var wn := TAU * freq_hz
	return Vector2(wn * wn, 2.0 * ratio * wn)


func _recompute_constants() -> void:
	var g := _gains(angular_frequency_hz, angular_damping_ratio)
	_ang_k = g.x
	_ang_c = g.y

	g = _gains(linear_frequency_hz, linear_damping_ratio)
	_lin_k = g.x
	_lin_c = g.y

	g = _gains(foot_linear_frequency_hz, foot_linear_damping_ratio)
	_foot_k = g.x
	_foot_c = g.y

	g = _gains(angular_frequency_hz * upper_body_stiffness_scale, angular_damping_ratio)
	_spine_ang_k = g.x
	_spine_ang_c = g.y

	g = _gains(leg_angular_frequency_hz, leg_angular_damping_ratio)
	_leg_ang_k = g.x
	_leg_ang_c = g.y

	g = _gains(foot_angular_frequency_hz, leg_angular_damping_ratio)
	_foot_ang_k = g.x
	_foot_ang_c = g.y

	g = _gains(hips_angular_frequency_hz, leg_angular_damping_ratio)
	_hips_ang_k = g.x
	_hips_ang_c = g.y

	g = _gains(leg_linear_frequency_hz, leg_linear_damping_ratio)
	_leg_lin_k = g.x
	_leg_lin_c = g.y


func _leg_softness() -> float:
	if gait == null:
		return 1.0

	return lerpf(1.0, landing_leg_softness, gait.landing_amount)


func _bone_ang_k(bone: PhysicalBone3D) -> float:
	if bone in spine_bones:
		return _spine_ang_k

	if bone == hips:
		return _hips_ang_k

	var soft := _leg_softness()

	if bone in feet_bones:
		return _foot_ang_k * soft * soft

	if bone in leg_bones:
		return _leg_ang_k * soft * soft

	return _ang_k


func _bone_ang_c(bone: PhysicalBone3D) -> float:
	if bone in spine_bones:
		return _spine_ang_c

	if bone == hips:
		return _hips_ang_c

	var soft := _leg_softness()

	if bone in feet_bones:
		return _foot_ang_c * soft

	if bone in leg_bones:
		return _leg_ang_c * soft

	return _ang_c


func is_on_floor() -> bool:
	if player_body:
		return player_body.is_on_floor()

	return _on_floor


func body_position() -> Vector3:
	if hips:
		return hips.global_position

	return global_position


func body_basis() -> Basis:
	if hips:
		return hips.global_transform.basis.orthonormalized()

	return global_basis


func animated_hips_position() -> Vector3:
	if _anim_hips_idx >= 0 and _anim_hips_idx < _anim_poses.size():
		return (_anim_xform * _anim_poses[_anim_hips_idx]).origin

	return body_position()


func measure_leg_length() -> float:
	var up := -1
	var knee := -1
	var foot := -1
	for i in animated_skeleton.get_bone_count():
		var n := animated_skeleton.get_bone_name(i)

		if n.ends_with("LeftUpLeg"):
			up = i
		elif n.ends_with("LeftLeg"):
			knee = i
		elif n.ends_with("LeftFoot"):
			foot = i

	if up < 0 or knee < 0 or foot < 0:
		return -1.0

	var a := animated_skeleton.get_bone_global_rest(up).origin
	var b := animated_skeleton.get_bone_global_rest(knee).origin
	var c := animated_skeleton.get_bone_global_rest(foot).origin

	var scale_y := animated_skeleton.global_basis.get_scale().y

	return ((a - b).length() + (b - c).length()) * scale_y


func _air_tuck_amount() -> float:
	if gait == null or not air_tuck_legs:
		return 0.0

	return gait.air_tuck


func _apply_air_tuck(bone: PhysicalBone3D, target: Transform3D) -> Transform3D:
	var tuck := _air_tuck_amount()
	if tuck <= 0.001:
		return target

	var dir_sign := 0.0
	if bone in thigh_bones:
		dir_sign = 1.0
	elif bone in shin_bones:
		dir_sign = -1.0
	else:
		return target

	var axis := Vector3.DOWN.cross(gait.air_fwd)
	if axis.length_squared() < 0.0001:
		return target

	axis = axis.normalized()

	var idx: int = bone_indices[bone]
	var skel_basis := animated_skeleton.global_transform.basis.orthonormalized()
	var rest_body := skel_basis \
			* animated_skeleton.get_bone_global_rest(idx).basis.orthonormalized() \
			* bone.body_offset.basis.orthonormalized()

	var tuck_q := (
		Basis(axis, dir_sign * gait.air_half_angle) * rest_body
	).get_rotation_quaternion()

	var anim_q := target.basis.get_rotation_quaternion()

	target.basis = Basis(anim_q.slerp(tuck_q, tuck))

	return target


func animated_leg_root(slot: int) -> Vector3:
	var i := _anim_upleg_idx[slot]
	if i >= 0 and i < _anim_poses.size():
		return (_anim_xform * _anim_poses[i]).origin

	return animated_hips_position()


func com() -> Vector3:
	return body_position()


func com_velocity() -> Vector3:
	return Vector3(_hips_vel_smooth.x, 0.0, _hips_vel_smooth.z)


func _physics_process(delta: float) -> void:
	_update_state(delta)

	for bone in physical_bones:
		if not bone_indices.has(bone):
			continue

		var target := _target_body_transform(bone)
		target = _apply_air_tuck(bone, target)

		_update_feedforward(bone, target, delta)
		_apply_angular_track(bone, target, delta)

		if bone == hips:
			_track_linear(bone, target, _lin_k, _lin_c, 1.0, delta)
			_apply_upright_torque(bone, delta, upright_torque, upright_damping)
		elif bone in spine_bones:
			_apply_upright_torque(bone, delta, spine_upright_torque, spine_upright_damping)
		elif bone in feet_bones:
			if foot_linear_assist > 0.0:
				_track_linear(
					bone,
					target,
					_foot_k,
					_foot_c,
					foot_linear_assist * _leg_softness(),
					delta,
					max_leg_track_speed,
				)
		elif bone in leg_bones:
			if leg_linear_assist > 0.0:
				_track_linear(
					bone,
					target,
					_leg_lin_k,
					_leg_lin_c,
					leg_linear_assist * _leg_softness() * (1.0 - _air_tuck_amount()),
					delta,
					max_leg_track_speed,
				)


func _update_feedforward(bone: PhysicalBone3D, target: Transform3D, delta: float) -> void:
	var dt := maxf(delta, 0.0001)
	var blend := 1.0 - exp(-feedforward_smoothing_hz * delta)

	var q := target.basis.get_rotation_quaternion()
	var o := target.origin

	if _ff_prev_q.has(bone):
		var prev_q: Quaternion = _ff_prev_q[bone]
		var dq := q * prev_q.inverse()

		if dq.w < 0.0:
			dq = -dq

		var w := dq.get_axis() * dq.get_angle() / dt
		if w.length() > max_ff_angular_speed:
			w = w.normalized() * max_ff_angular_speed

		var v: Vector3 = (o - (_ff_prev_o[bone] as Vector3)) / dt

		_ff_ang[bone] = (_ff_ang[bone] as Vector3).lerp(w, blend)
		_ff_lin[bone] = (_ff_lin[bone] as Vector3).lerp(v, blend)
	else:
		_ff_ang[bone] = Vector3.ZERO
		_ff_lin[bone] = player_body.velocity if player_body else Vector3.ZERO

	_ff_prev_q[bone] = q
	_ff_prev_o[bone] = o


func _apply_angular_track(bone: PhysicalBone3D, target: Transform3D, delta: float) -> void:
	var k := _bone_ang_k(bone)
	var c := _bone_ang_c(bone)
	var ff: Vector3 = (_ff_ang.get(bone, Vector3.ZERO) as Vector3) * feedforward

	var current_q := bone.global_transform.basis.get_rotation_quaternion()
	var target_q := target.basis.get_rotation_quaternion()

	var diff := target_q * current_q.inverse()
	if diff.w < 0.0:
		diff = -diff

	var err := diff.get_axis() * diff.get_angle()

	var rel := bone.angular_velocity - ff
	rel = (rel + err * k * delta) / (1.0 + c * delta)
	bone.angular_velocity = rel + ff


func _track_linear(
	bone: PhysicalBone3D,
	target: Transform3D,
	k: float,
	c: float,
	assist: float,
	delta: float,
	max_rel := INF,
) -> void:
	var body_v := player_body.velocity if player_body else Vector3.ZERO
	var ff_v: Vector3 = _ff_lin.get(bone, body_v)

	var target_v := body_v.lerp(ff_v, feedforward)
	var rel_v := bone.linear_velocity - target_v

	var pos_error: Vector3 = target.origin - bone.global_position
	rel_v = (rel_v + pos_error * k * delta) / (1.0 + c * delta)

	if max_rel < INF:
		rel_v = rel_v.limit_length(max_rel)

	bone.linear_velocity = bone.linear_velocity.lerp(rel_v + target_v, assist)


func _upright_reference() -> Vector3:
	if gait and absf(gait.lean_angle) > 0.001 and gait.lean_axis.length_squared() > 0.0001:
		return (Basis(gait.lean_axis.normalized(), gait.lean_angle) * Vector3.UP).normalized()

	return Vector3.UP


func _apply_upright_torque(
	bone: PhysicalBone3D,
	delta: float,
	strength: float,
	damping: float,
) -> void:
	var up := bone.global_transform.basis.y
	if up.length_squared() < 0.0001:
		return

	up = up.normalized()

	var ref_up := _upright_reference()
	var axis := up.cross(ref_up)
	if axis.length_squared() < 0.000001:
		return

	axis = axis.normalized()

	var angle := up.signed_angle_to(ref_up, axis)
	var correction := axis * angle * strength
	correction -= bone.angular_velocity * damping

	bone.angular_velocity += correction * delta


func _update_state(delta: float) -> void:
	if player_body:
		desired_speed = player_body.desired_speed if "desired_speed" in player_body else 0.0
		_on_floor = player_body.is_on_floor()

	if hips:
		var hp := hips.global_position
		var inst_v := (hp - _prev_hips_pos) / maxf(delta, 0.0001)

		_prev_hips_pos = hp
		_hips_vel_smooth = _hips_vel_smooth.lerp(inst_v, 1.0 - exp(-18.0 * delta))

		velocity = _hips_vel_smooth


func _target_body_transform(bone: PhysicalBone3D) -> Transform3D:
	var idx: int = bone_indices[bone]
	var target_bone_global: Transform3D

	if _anim_poses.size() > idx:
		target_bone_global = _anim_xform * _anim_poses[idx]
	else:
		target_bone_global = animated_skeleton.global_transform \
				* animated_skeleton.get_bone_global_pose(idx)

	return target_bone_global * bone.body_offset


func _on_animated_skeleton_updated() -> void:
	var n := animated_skeleton.get_bone_count()
	_anim_poses.resize(n)

	for i in n:
		_anim_poses[i] = animated_skeleton.get_bone_global_pose(i)

	_anim_xform = animated_skeleton.global_transform


func set_self_collision(enabled: bool) -> void:
	for bone in physical_bones:
		bone.collision_mask = 1 | (2 if enabled else 0)
