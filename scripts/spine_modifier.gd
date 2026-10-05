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

@export var breath_degrees := 2
@export var breath_speed := 1.7

@export_group("Aim")
@export var head_forward_tilt := 3.0

@export var head_max_relative_degrees := 38.0
@export var max_aim_up_degrees := 80.0
@export var max_aim_down_degrees := 70.0

@export_range(0.0, 1.0) var head_level := 0.55
@export_range(0.0, 1.0) var head_aim_share := 0.75
@export_range(0.0, 1.0) var chest_aim_share := 0.3


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

@export var always_aim := false

@export var aim_action: StringName = &"aim"
@export var aim_blend_speed := 9.0

@export var aim_reach_front := 0.42
@export var aim_reach_back := 0.34

@export_range(0.0, 1.0) var aim_hand_spread := 0.25
@export var aim_back_hand_drop := 0.04

@export var aim_hand_drop := 0.09
@export var aim_bob := 0.012

@export var hand_roll_degrees := 80.0

@export_group("Arms relaxed")
@export var arm_swing_degrees := 14.0
@export var arm_rest_forward_degrees := 4.0
@export var elbow_bend_idle_degrees := 8.0
@export var elbow_bend_run_degrees := 28.0
@export var elbow_bend_crouch_degrees := 20.0

@export var arm_side_offset := 0.16
@export var crouch_arm_forward_degrees := 8.0

@export_group("Arms air")
@export var air_arm_raise_degrees := 22.0
@export var air_arm_spread := 0.3
@export var air_elbow_degrees := 20.0
@export var landing_arm_forward_degrees := 15.0

@export_range(0.0, 1.0) var aim_air_arm_share := 0.25

var _chain: Array[int] = []
var _head_tip := -1
var _left: Array[int] = []
var _right: Array[int] = []

var _chest_off := 0.0
var _head_off := 0.0
var _aim := 0.0
var _aim_amt := 0.0
var _clock := 0.0

var _rest_lean: Array[float] = []
var _upper_len := { }
var _fore_len := { }


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
		_upper_len[c[0]] = (
			skel.get_bone_global_rest(c[1]).origin - skel.get_bone_global_rest(c[0]).origin
		).length()
		_fore_len[c[0]] = (
			skel.get_bone_global_rest(c[2]).origin - skel.get_bone_global_rest(c[1]).origin
		).length()

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

	var pitch := 0.0
	if "aim_pitch" in player:
		pitch = clampf(
			float(player.aim_pitch),
			-deg_to_rad(max_aim_down_degrees),
			deg_to_rad(max_aim_up_degrees),
		)

	_aim = lerpf(_aim, pitch, 1.0 - exp(-smoothing_speed * dt))

	var aiming := always_aim or Input.is_action_pressed(aim_action)
	_aim_amt = lerpf(_aim_amt, 1.0 if aiming else 0.0, 1.0 - exp(-aim_blend_speed * dt))

	_apply_spine(skel, dt)

	var near_left := smoothstep(-0.6, 0.6, skel.global_transform.basis.orthonormalized().x.z)
	_apply_arm(skel, _left, 1.0, near_left)
	_apply_arm(skel, _right, -1.0, 1.0 - near_left)


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
	var chest_target := _posture_lean() - _aim * chest_aim_share
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


func _apply_arm(skel: Skeleton3D, chain: Array[int], side: float, near: float) -> void:
	var speed := _g("speed_ratio")
	var crouch := _g("crouch_amount")
	var air := _g("air_amount")
	var land := _g("landing_amount")
	var vy := _g("vertical_speed")

	var shoulder := skel.get_bone_global_pose(chain[0]).origin

	var phase := -side * _g("foot_phase")
	var swing := deg_to_rad(arm_swing_degrees) * phase * clampf(speed * 1.6, 0.0, 1.0)
	swing += deg_to_rad(arm_rest_forward_degrees)
	swing += deg_to_rad(crouch_arm_forward_degrees) * crouch

	var bend := lerpf(elbow_bend_idle_degrees, elbow_bend_run_degrees, smoothstep(0.2, 1.0, speed))
	bend = deg_to_rad(lerpf(bend, elbow_bend_crouch_degrees, crouch))
	var spread := arm_side_offset

	var air_share := lerpf(1.0, aim_air_arm_share, _aim_amt)
	var a := air * air_share
	var l := land * (1.0 - air) * air_share

	if a > 0.001 or l > 0.001:
		var rising := clampf(vy / 3.0, -1.0, 1.0) * 0.5 + 0.5
		var raise := deg_to_rad(air_arm_raise_degrees) * lerpf(1.0, 0.75, rising)

		swing = lerpf(swing, raise, a)
		bend = lerpf(bend, deg_to_rad(air_elbow_degrees), a)
		spread = lerpf(spread, air_arm_spread, a)

		swing = lerpf(swing, deg_to_rad(landing_arm_forward_degrees), l)
		bend = lerpf(bend, deg_to_rad(20.0), l)

	var lateral := Vector3(side * spread, 0.0, 0.0)
	var upper := (lateral + Vector3(0.0, -cos(swing), sin(swing))).normalized()
	var fore := (lateral + Vector3(0.0, -cos(swing + bend), sin(swing + bend))).normalized()

	if _aim_amt > 0.001:
		var ua: float = _upper_len[chain[0]]
		var fa: float = _fore_len[chain[0]]

		var aim_dir := Vector3(0.0, sin(_aim), cos(_aim))
		var reach := lerpf(aim_reach_back, aim_reach_front, near)

		var hand := shoulder + aim_dir * reach
		hand.x = lerpf(0.0, shoulder.x, aim_hand_spread)
		hand.y += aim_bob * speed * _g("foot_phase") * -side
		hand.y -= aim_hand_drop + aim_back_hand_drop * (1.0 - near)

		var elbow := _elbow_for(shoulder, hand, ua, fa)
		var aim_upper := (elbow - shoulder).normalized()
		var aim_fore := (hand - elbow).normalized()

		upper = upper.slerp(aim_upper, _aim_amt).normalized()
		fore = fore.slerp(aim_fore, _aim_amt).normalized()

	_point_bone(skel, chain[0], upper)
	_align_elbow(skel, chain[0], chain[1], upper, fore)
	_point_bone(skel, chain[1], fore)

	var wrist := skel.get_bone_global_pose(chain[2])
	wrist.basis = Basis(fore, deg_to_rad(hand_roll_degrees) * -side) * wrist.basis
	skel.set_bone_global_pose(chain[2], wrist)


func _elbow_for(shoulder: Vector3, hand: Vector3, upper_len: float, fore_len: float) -> Vector3:
	var to_hand := hand - shoulder
	var dist := clampf(to_hand.length(), 0.05, upper_len + fore_len - 0.002)
	var dir := to_hand.normalized()

	var along := (upper_len * upper_len + dist * dist - fore_len * fore_len) / (2.0 * dist)
	var height := sqrt(maxf(upper_len * upper_len - along * along, 0.0))

	var pole := Vector3.DOWN
	pole -= dir * pole.dot(dir)
	if pole.length_squared() < 0.0001:
		pole = Vector3.BACK

	return shoulder + dir * along + pole.normalized() * height


func _align_elbow(
	skel: Skeleton3D,
	upper_idx: int,
	fore_idx: int,
	upper_dir: Vector3,
	fore_dir: Vector3,
) -> void:
	var key := StringName("hinge_axis_" + String(skel.get_bone_name(fore_idx)))
	if not skel.has_meta(key):
		return

	var axis_local: Vector3 = skel.get_meta(key)

	var upper := skel.get_bone_global_pose(upper_idx)
	var fore := skel.get_bone_global_pose(fore_idx)

	var d := (fore.origin - upper.origin).normalized()
	var hinge := (fore.basis * axis_local).normalized()

	var wanted := upper_dir.cross(fore_dir)
	if wanted.length_squared() < 0.0004:
		wanted = Vector3.RIGHT
	wanted = wanted.normalized()

	var a := hinge - d * d.dot(hinge)
	var z := wanted - d * d.dot(wanted)
	if a.length_squared() < 0.0001 or z.length_squared() < 0.0001:
		return

	var phi := a.signed_angle_to(z, d)

	if phi > PI * 0.5:
		phi -= PI
	elif phi < -PI * 0.5:
		phi += PI

	upper.basis = Basis(d, phi) * upper.basis
	skel.set_bone_global_pose(upper_idx, upper)


func _point_bone(skel: Skeleton3D, idx: int, desired: Vector3) -> void:
	var kids := skel.get_bone_children(idx)
	if kids.is_empty():
		return

	var pose := skel.get_bone_global_pose(idx)
	var cur := skel.get_bone_global_pose(kids[0]).origin - pose.origin
	if cur.length_squared() < 0.0000001:
		return

	pose.basis = Basis(Quaternion(cur.normalized(), desired.normalized())) * pose.basis
	skel.set_bone_global_pose(idx, pose)
