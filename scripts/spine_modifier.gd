class_name SpineModifier
extends SkeletonModifier3D

@export var player: Node3D
@export var gait: Node

@export_group("Spine")
@export var spine_bone_names: Array[StringName] = [
	&"mixamorig7_Spine",
	&"mixamorig7_Spine1",
	&"mixamorig7_Spine2",
	&"mixamorig7_Neck",
	&"mixamorig7_Head",
]

@export var head_tip_bone: StringName = &"mixamorig7_HeadTop_End"

@export var torso_shares: Array[float] = [0.35, 0.45, 0.2]
@export var smoothing_speed := 10.0

@export_group("Posture")
@export var idle_lean := 15.0
@export var walk_lean := 25.0
@export var run_lean := 40.0

@export var backpedal_lean := 5.0

@export var crouch_lean := 26.0
@export var landing_lean := 16.0

@export var rising_lean := 4.0
@export var falling_lean := 7.0

@export var breath_degrees := 2.0
@export var breath_speed := 1.7

@export_group("Aim")
@export var aim_smoothing := 25.0
@export var aim_from_muzzle := true

@export var max_aim_up_degrees := 80.0
@export var max_aim_down_degrees := 70.0

@export var head_forward_tilt := 3.0
@export var head_max_relative_degrees := 38.0

@export_range(0.0, 1.0) var head_level := 0.55
@export_range(0.0, 1.0) var head_aim_share := 0.75
@export_range(0.0, 1.0) var chest_aim_share := 0.4
@export_range(0.0, 1.0) var chest_aim_share_down := 0.12

@export_group("Arms")
@export var left_arm_bones: Array[StringName] = [
	&"mixamorig7_LeftArm",
	&"mixamorig7_LeftForeArm",
	&"mixamorig7_LeftHand",
]
@export var right_arm_bones: Array[StringName] = [
	&"mixamorig7_RightArm",
	&"mixamorig7_RightForeArm",
	&"mixamorig7_RightHand",
]

@export_group("Hold")
@export var hold_reach := 0.45
@export var hold_drop := 0.05
@export var hold_side := 0.0

@export_range(0.6, 1.0) var max_arm_extension := 0.97

@export var hold_up_limit_degrees := 85.0
@export var hold_down_limit_degrees := 85.0

@export var elbow_flare_degrees := -60.0
@export var elbow_back := 0.3

@export var breath_sway := 0.004
@export var landing_dip := 0.04

var gun_equipped := false
var gun_anchor := Vector3.ZERO
var gun_muzzle := Vector3.ZERO

var hold_main := Transform3D.IDENTITY
var hold_support := Transform3D.IDENTITY

var gun_pose := Transform3D.IDENTITY

var _chain: Array[int] = []
var _head_tip := -1
var _left: Array[int] = []
var _right: Array[int] = []

var _chest_off := 0.0
var _head_off := 0.0
var _aim := 0.0
var _clock := 0.0

var _muzzle_skel := Vector3.ZERO

var _rest_lean: Array[float] = []
var _upper_len := { }
var _fore_len := { }
var _rest_bend := { }
var _rest_hand := { }


func _ready() -> void:
	_fix_modifier_order.call_deferred()


func _fix_modifier_order() -> void:
	var parent := get_parent()
	if parent == null:
		return

	var hips_at := -1
	for c in parent.get_children():
		if c is HipsModifier:
			hips_at = c.get_index()

	if hips_at > get_index():
		parent.move_child(self, hips_at)


func _g(prop: String) -> float:
	if gait == null:
		return 0.0

	var v: Variant = gait.get(prop)
	return float(v) if v != null else 0.0


func _resolve(skel: Skeleton3D) -> bool:
	if not _chain.is_empty():
		return true

	var ids: Array[int] = []
	for n in spine_bone_names:
		var i := skel.find_bone(n)
		if i < 0:
			return false

		ids.append(i)

	_head_tip = skel.find_bone(head_tip_bone)
	if _head_tip < 0:
		return false

	_left = _resolve_arm(skel, left_arm_bones)
	_right = _resolve_arm(skel, right_arm_bones)
	if _left.size() < 3 or _right.size() < 3:
		return false

	_rest_lean.clear()
	for k in ids.size():
		var next := _head_tip if k == ids.size() - 1 else ids[k + 1]
		var d := skel.get_bone_global_rest(next).origin - skel.get_bone_global_rest(ids[k]).origin
		_rest_lean.append(atan2(d.z, d.y))

	for chain in [_left, _right]:
		var c: Array[int] = chain
		var upper := skel.get_bone_global_rest(c[0])
		var fore := skel.get_bone_global_rest(c[1])
		var hand := skel.get_bone_global_rest(c[2])

		_upper_len[c[0]] = (fore.origin - upper.origin).length()
		_fore_len[c[0]] = (hand.origin - fore.origin).length()

		_rest_bend[c[0]] = upper.basis.orthonormalized().inverse() * fore.basis.orthonormalized()
		_rest_hand[c[0]] = hand.basis.orthonormalized()

	_chain = ids
	return true


func _resolve_arm(skel: Skeleton3D, names: Array[StringName]) -> Array[int]:
	var out: Array[int] = []
	for n in names:
		var i := skel.find_bone(n)
		if i >= 0:
			out.append(i)

	return out


func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null or player == null or not _resolve(skel):
		return

	if gait == null:
		for c in player.get_children():
			if "foot_phase" in c:
				gait = c
				break

	var dt := get_process_delta_time()
	if skel.modifier_callback_mode_process == Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_PHYSICS:
		dt = get_physics_process_delta_time()

	_clock += dt

	_aim = lerpf(_aim, _target_pitch(skel), 1.0 - exp(-aim_smoothing * dt))

	_apply_spine(skel, dt)

	if gun_equipped:
		_hold_gun(skel)
	else:
		_lower_arms(skel)


func _target_pitch(skel: Skeleton3D) -> float:
	var pitch := 0.0
	if "aim_pitch" in player:
		pitch = float(player.aim_pitch)

	if aim_from_muzzle and gun_equipped and "aim_point" in player and "facing" in player:
		var muzzle := skel.global_transform * _muzzle_skel
		var to: Vector3 = (player.aim_point as Vector3) - muzzle
		var ahead := to.x * float(player.facing)

		pitch = lerp_angle(pitch, atan2(to.y, maxf(ahead, 0.001)), smoothstep(0.3, 1.0, ahead))

	return clampf(pitch, -deg_to_rad(max_aim_down_degrees), deg_to_rad(max_aim_up_degrees))


func _posture_lean() -> float:
	var speed := _g("speed_ratio")
	var crouch := _g("crouch_amount")
	var air := _g("air_amount")
	var land := _g("landing_amount")
	var vy := _g("vertical_speed")

	var deg := idle_lean
	deg = lerpf(deg, walk_lean, clampf(speed * 3.0, 0.0, 1.0))
	deg = lerpf(deg, run_lean, smoothstep(0.45, 1.0, speed))

	if "moving_backward" in player and player.moving_backward:
		deg = lerpf(deg, backpedal_lean, clampf(speed * 3.0, 0.0, 1.0))

	deg = lerpf(deg, crouch_lean, crouch)
	deg += landing_lean * land

	var rising := clampf(vy / 3.0, -1.0, 1.0)
	deg += air * (rising_lean * maxf(rising, 0.0) + falling_lean * maxf(-rising, 0.0))
	deg += breath_degrees * sin(_clock * breath_speed)

	return deg_to_rad(deg)


func _apply_spine(skel: Skeleton3D, dt: float) -> void:
	var chest_share := chest_aim_share if _aim > 0.0 else chest_aim_share_down
	var chest_target := _posture_lean() - _aim * chest_share
	var head_target := (
		chest_target * (1.0 - head_level) - _aim * head_aim_share + deg_to_rad(head_forward_tilt)
	)

	var max_rel := deg_to_rad(head_max_relative_degrees)
	head_target = chest_target + clampf(head_target - chest_target, -max_rel, max_rel)

	var k := 1.0 - exp(-smoothing_speed * dt)
	_chest_off = lerpf(_chest_off, chest_target, k)
	_head_off = lerpf(_head_off, head_target, k)

	var cum := 0.0
	var targets: Array[float] = []
	for i in _chain.size():
		var t := 0.0
		if i < 3:
			cum += torso_shares[i] if i < torso_shares.size() else 0.0
			t = _chest_off * cum
		elif i == 3:
			t = lerpf(_chest_off, _head_off, 0.5)
		else:
			t = _head_off

		targets.append(t)

	for i in _chain.size():
		var next := _head_tip if i == _chain.size() - 1 else _chain[i + 1]
		var d := (
			skel.get_bone_global_pose(next).origin - skel.get_bone_global_pose(_chain[i]).origin
		)
		var delta := (_rest_lean[i] + targets[i]) - atan2(d.z, d.y)
		if absf(delta) < 0.00001:
			continue

		var pose := skel.get_bone_global_pose(_chain[i])
		pose.basis = Basis(Vector3.RIGHT, delta) * pose.basis
		skel.set_bone_global_pose(_chain[i], pose)


func _hold_gun(skel: Skeleton3D) -> void:
	var s_left := skel.get_bone_global_pose(_left[0]).origin
	var s_right := skel.get_bone_global_pose(_right[0]).origin
	var mid := (s_left + s_right) * 0.5

	var aim := Vector3(0.0, sin(_aim), cos(_aim))
	var up := Vector3(0.0, cos(_aim), -sin(_aim))
	var frame := Basis(aim, up, aim.cross(up))

	var held := _held_pitch()
	var held_aim := Vector3(0.0, sin(held), cos(held))
	var held_up := Vector3(0.0, cos(held), -sin(held))
	var held_frame := Basis(held_aim, held_up, held_aim.cross(held_up))

	var lift := breath_sway * sin(_clock * breath_speed) - landing_dip * _g("landing_amount")

	var wrist_main := frame * (hold_main.origin - gun_anchor)
	var wrist_support := frame * (hold_support.origin - gun_anchor)

	var limit_left: float = (_upper_len[_left[0]] + _fore_len[_left[0]]) * max_arm_extension
	var limit_right: float = (_upper_len[_right[0]] + _fore_len[_right[0]]) * max_arm_extension

	var reach := hold_reach
	var anchor := Vector3.ZERO
	for i in 4:
		anchor = mid + held_frame * Vector3(reach, lift - hold_drop, hold_side)

		var over := maxf(
			(anchor + wrist_support - s_left).length() - limit_left,
			(anchor + wrist_main - s_right).length() - limit_right,
		)
		if over <= 0.0:
			break

		reach = maxf(reach - over, 0.15)

	gun_pose = Transform3D(frame, anchor - frame * gun_anchor)
	_muzzle_skel = gun_pose * gun_muzzle

	var turn := deg_to_rad(elbow_flare_degrees)
	var pole_right := _elbow_pole(held_up, -held_frame.z, turn)
	var pole_left := _elbow_pole(held_up, held_frame.z, turn)

	_solve_arm(skel, _right, pole_right, gun_pose * hold_main.origin, frame * hold_main.basis)
	_solve_arm(skel, _left, pole_left, gun_pose * hold_support.origin, frame * hold_support.basis)


func _lower_arms(skel: Skeleton3D) -> void:
	for side in [1.0, -1.0]:
		var chain: Array[int] = _left if side > 0.0 else _right
		var shoulder := skel.get_bone_global_pose(chain[0]).origin
		var reach: float = (_upper_len[chain[0]] + _fore_len[chain[0]]) * 0.9

		var wrist := shoulder + Vector3(side * 0.05, -reach, 0.08)
		var pole := Vector3(side * 0.4, -1.0, -elbow_back)
		_solve_arm(skel, chain, pole, wrist, _rest_hand[chain[0]])


func _held_pitch() -> float:
	var limit := deg_to_rad(hold_up_limit_degrees if _aim > 0.0 else hold_down_limit_degrees)
	return limit * tanh(_aim / limit)


func _elbow_pole(up: Vector3, out: Vector3, turn: float) -> Vector3:
	return -up * cos(turn) + out * sin(turn) + Vector3(0.0, 0.0, -elbow_back)


func _solve_arm(
	skel: Skeleton3D,
	chain: Array[int],
	pole_hint: Vector3,
	wrist: Vector3,
	hand_basis: Basis,
) -> void:
	var upper_len: float = _upper_len[chain[0]]
	var fore_len: float = _fore_len[chain[0]]
	var shoulder := skel.get_bone_global_pose(chain[0]).origin

	var to := wrist - shoulder
	var dist := clampf(
		to.length(),
		absf(upper_len - fore_len) + 0.02,
		(upper_len + fore_len) * 0.9995,
	)
	var dir := to.normalized() if to.length_squared() > 0.000001 else Vector3.BACK

	var along := (upper_len * upper_len + dist * dist - fore_len * fore_len) / (2.0 * dist)
	var height := sqrt(maxf(upper_len * upper_len - along * along, 0.0))

	var pole := pole_hint - dir * pole_hint.dot(dir)
	if pole.length_squared() < 0.000001:
		pole = dir.cross(Vector3.RIGHT)

	pole = pole.normalized()

	var elbow := shoulder + dir * along + pole * height
	var upper_dir := (elbow - shoulder).normalized()
	var fore_dir := (shoulder + dir * dist - elbow).normalized()

	var bend_axis := pole.cross(dir).normalized()
	var hinge := _hinge_axis(skel, chain[1])

	var local := Basis(Vector3.UP, hinge, Vector3.UP.cross(hinge))
	var wanted := Basis(fore_dir, bend_axis, fore_dir.cross(bend_axis))
	var fore_basis := wanted * local.transposed()

	var bend := acos(clampf(upper_dir.dot(fore_dir), -1.0, 1.0))
	var rest_bend: Basis = _rest_bend[chain[0]]
	var upper_basis := fore_basis * Basis(hinge, -bend) * rest_bend.inverse()
	upper_basis = Basis(Quaternion(upper_basis * Vector3.UP, upper_dir)) * upper_basis

	_set_basis(skel, chain[0], upper_basis)
	_set_basis(skel, chain[1], fore_basis)
	_set_basis(skel, chain[2], hand_basis)


func _hinge_axis(skel: Skeleton3D, fore: int) -> Vector3:
	var bone_name := String(skel.get_bone_name(fore))
	var key := StringName("hinge_axis_" + bone_name)
	var axis := Vector3.BACK if bone_name.contains("Left") else Vector3.FORWARD
	if skel.has_meta(key):
		axis = (skel.get_meta(key) as Vector3).normalized()

	axis -= Vector3.UP * axis.dot(Vector3.UP)
	return axis.normalized() if axis.length_squared() > 0.0001 else Vector3.BACK


func _set_basis(skel: Skeleton3D, idx: int, basis: Basis) -> void:
	var pose := skel.get_bone_global_pose(idx)
	pose.basis = basis.orthonormalized()
	skel.set_bone_global_pose(idx, pose)
