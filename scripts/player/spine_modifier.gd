class_name SpineModifier
extends SkeletonModifier3D

@export var player: PlayerMovement
@export var gait: GaitDriver

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

@export var crouch_lean := 46.0
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

@export_group("Aim down sights")
@export var ads_chest_lean_degrees := 14.0
@export var ads_head_tilt_degrees := 10.0

@export var eye_up := 0.12
@export var ads_eye_distance := 0.22
@export var eye_forward := 0.08

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
@export var hold_reach := 0.5
@export var hold_drop := 0.05
@export var hold_side := 0.0

@export_range(0.6, 1.0) var max_arm_extension := 0.97

@export var hold_up_limit_degrees := 85.0
@export var hold_down_limit_degrees := 85.0

@export var elbow_flare_degrees := -60.0
@export var elbow_back := 0.3

@export var breath_sway := 0.004
@export var landing_dip := 0.04

@export_group("Recoil")
@export var recoil_arm_follow := 18.0
@export_range(0.0, 1.0) var recoil_arm_share := 0.2
@export_range(0.0, 1.0) var recoil_wrist_pivot := 1.0
@export_range(0.0, 1.0) var recoil_head_share := 0.45

var recoil: WeaponRecoil
var reload: WeaponReload

var gun_equipped := false
var gun_anchor := Vector3.ZERO
var gun_muzzle := Vector3.ZERO
var gun_sight := Vector3.ZERO

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
var _arm_flip := 0.0

var _muzzle_skel := Vector3.ZERO

var _rest_lean: Array[float] = []
var _upper_len := { }
var _fore_len := { }
var _rest_bend := { }
var _rest_hand := { }


func _resolve(skel: Skeleton3D) -> void:
	var ids: Array[int] = []
	for n in spine_bone_names:
		ids.append(skel.find_bone(n))

	_head_tip = skel.find_bone(head_tip_bone)
	_left = _resolve_arm(skel, left_arm_bones)
	_right = _resolve_arm(skel, right_arm_bones)

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


func _resolve_arm(skel: Skeleton3D, names: Array[StringName]) -> Array[int]:
	var out: Array[int] = []
	for n in names:
		out.append(skel.find_bone(n))

	return out


func _process_modification() -> void:
	var skel := get_skeleton()
	if _chain.is_empty():
		_resolve(skel)

	var dt := get_physics_process_delta_time()
	_clock += dt

	_aim = lerpf(_aim, _target_pitch(skel), 1.0 - exp(-aim_smoothing * dt))

	_apply_spine(skel, dt)

	if gun_equipped:
		_hold_gun(skel, dt)
	else:
		_lower_arms(skel)


func _target_pitch(skel: Skeleton3D) -> float:
	var pitch := player.aim_pitch
	if aim_from_muzzle and gun_equipped:
		var muzzle := skel.global_transform * _muzzle_skel
		var to := player.aim_point - muzzle
		var ahead := to.x * float(player.facing)

		pitch = lerp_angle(pitch, atan2(to.y, maxf(ahead, 0.001)), smoothstep(0.3, 1.0, ahead))

	return clampf(pitch, -deg_to_rad(max_aim_down_degrees), deg_to_rad(max_aim_up_degrees))


func _posture_lean() -> float:
	var speed := gait.speed_ratio
	var crouch := gait.crouch_amount
	var air := gait.air_amount
	var land := gait.landing_amount
	var vy := gait.vertical_speed

	var deg := idle_lean
	deg = lerpf(deg, walk_lean, clampf(speed * 3.0, 0.0, 1.0))
	deg = lerpf(deg, run_lean, smoothstep(0.45, 1.0, speed))

	if player.moving_backward:
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
	chest_target += deg_to_rad(ads_chest_lean_degrees) * player.aim_amount
	var head_target := (
		chest_target * (1.0 - head_level) - _aim * head_aim_share + deg_to_rad(head_forward_tilt)
	)
	head_target += deg_to_rad(ads_head_tilt_degrees) * player.aim_amount

	var max_rel := deg_to_rad(head_max_relative_degrees)
	head_target = chest_target + clampf(head_target - chest_target, -max_rel, max_rel)

	var k := 1.0 - exp(-smoothing_speed * dt)
	_chest_off = lerpf(_chest_off, chest_target, k)
	_head_off = lerpf(_head_off, head_target, k)

	var back := recoil.torso
	var chest := _chest_off - back
	var head := _head_off - back * recoil_head_share

	var cum := 0.0
	var targets: Array[float] = []
	for i in _chain.size():
		var t := 0.0
		if i < 3:
			cum += torso_shares[i]
			t = chest * cum
		elif i == 3:
			t = lerpf(chest, head, 0.5)
		else:
			t = head

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


func _hold_gun(skel: Skeleton3D, dt: float) -> void:
	var s_left := skel.get_bone_global_pose(_left[0]).origin
	var s_right := skel.get_bone_global_pose(_right[0]).origin
	var mid := (s_left + s_right) * 0.5

	var flip := recoil.flip
	var slide := recoil.slide

	var tilt := reload.tilt
	var reload_pull := reload.pull
	var reload_hand := reload.active and reload.support_weight > 0.0

	var pitch := _aim + tilt + flip
	var aim := Vector3(0.0, sin(pitch), cos(pitch))
	var up := Vector3(0.0, cos(pitch), -sin(pitch))
	var frame := Basis(aim, up, aim.cross(up))

	var level := Vector3(0.0, sin(_aim + tilt), cos(_aim + tilt))
	var level_up := Vector3(0.0, cos(_aim + tilt), -sin(_aim + tilt))
	var level_frame := Basis(level, level_up, level.cross(level_up))

	_arm_flip = lerpf(_arm_flip, flip, 1.0 - exp(-recoil_arm_follow * dt))
	var held := _held_pitch() + tilt + _arm_flip * recoil_arm_share

	var held_aim := Vector3(0.0, sin(held), cos(held))
	var held_up := Vector3(0.0, cos(held), -sin(held))
	var held_frame := Basis(held_aim, held_up, held_aim.cross(held_up))

	var lift := breath_sway * sin(_clock * breath_speed) - landing_dip * gait.landing_amount

	var pivot := gun_anchor.lerp(hold_main.origin, recoil_wrist_pivot)
	var pivot_off := level_frame * (pivot - gun_anchor)

	var wrist_main := pivot_off + frame * (hold_main.origin - pivot)
	var wrist_support := pivot_off + frame * (hold_support.origin - pivot)

	var limit_left: float = (_upper_len[_left[0]] + _fore_len[_left[0]]) * max_arm_extension
	var limit_right: float = (_upper_len[_right[0]] + _fore_len[_right[0]]) * max_arm_extension

	var reach := hold_reach - slide - reload_pull
	var anchor := Vector3.ZERO
	for i in 4:
		anchor = mid + held_frame * Vector3(reach, lift - hold_drop, hold_side)

		var over_support := (anchor + wrist_support - s_left).length() - limit_left
		if reload_hand:
			over_support *= 1.0 - reload.support_weight

		var over := maxf(over_support, (anchor + wrist_main - s_right).length() - limit_right)
		if over <= 0.0:
			break

		reach = maxf(reach - over, 0.15)

	var pivot_world := anchor + pivot_off
	if player.aim_amount > 0.0:
		var sight_at := Vector3(ads_eye_distance, 0.0, 0.0) - gun_sight + pivot
		pivot_world = pivot_world.lerp(_eye(skel) + level_frame * sight_at, player.aim_amount)

	gun_pose = Transform3D(frame, pivot_world - frame * pivot)
	_muzzle_skel = gun_pose * gun_muzzle

	var turn := deg_to_rad(elbow_flare_degrees)
	var pole_right := _elbow_pole(held_up, -held_frame.z, turn)
	var pole_left := _elbow_pole(held_up, held_frame.z, turn)

	_solve_arm(skel, _right, pole_right, gun_pose * hold_main.origin, frame * hold_main.basis)
	var support_pos := gun_pose * hold_support.origin
	var support_basis := frame * hold_support.basis
	if reload_hand:
		var target := reload.support_pose(gun_pose, skel)
		var w := reload.support_weight
		support_pos = support_pos.lerp(target.origin, w)
		support_basis = support_basis.orthonormalized().slerp(target.basis.orthonormalized(), w)

	_solve_arm(skel, _left, pole_left, support_pos, support_basis)


func _eye(skel: Skeleton3D) -> Vector3:
	var head := skel.get_bone_global_pose(_chain[-1]).origin
	var up := (skel.get_bone_global_pose(_head_tip).origin - head).normalized()
	var forward := Vector3(0.0, -up.z, up.y)
	return head + up * eye_up + forward * eye_forward


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
	var fallback := Vector3.BACK if bone_name.contains("Left") else Vector3.FORWARD
	var axis := (skel.get_meta(key, fallback) as Vector3).normalized()

	axis -= Vector3.UP * axis.dot(Vector3.UP)
	return axis.normalized() if axis.length_squared() > 0.0001 else Vector3.BACK


func _set_basis(skel: Skeleton3D, idx: int, new_basis: Basis) -> void:
	var pose := skel.get_bone_global_pose(idx)
	pose.basis = new_basis.orthonormalized()
	skel.set_bone_global_pose(idx, pose)
