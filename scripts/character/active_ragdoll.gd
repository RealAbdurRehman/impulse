class_name ActiveRagdoll
extends PhysicalBoneSimulator3D

const CORPSE_LAYER := 32

@export_group("Tracking")
@export var max_gain_per_step := 3.0
@export var angular_frequency_hz := 6.5
@export var angular_damping_ratio := 1.15

@export var linear_frequency_hz := 6.0
@export var linear_damping_ratio := 1.15

@export var foot_linear_frequency_hz := 12.0
@export var foot_linear_damping_ratio := 1.0

@export_range(0.0, 1.0) var foot_linear_assist: float = 1.0

@export_group("Leg Strength")
@export_range(0.05, 1.0) var upper_leg_mass_scale := 0.1
@export_range(0.05, 1.0) var lower_leg_mass_scale := 0.2
@export_range(0.05, 1.0) var foot_mass_scale := 0.5
@export var legs_ignore_each_other := false

@export var foot_angular_frequency_hz := 18.0
@export var hips_angular_frequency_hz := 10.0

@export var leg_angular_frequency_hz := 12.0
@export var leg_angular_damping_ratio := 1.0

@export var leg_linear_frequency_hz := 12.0
@export var leg_linear_damping_ratio := 1.0

@export var max_leg_track_speed := 5.0

@export_range(0.2, 1.0) var landing_leg_softness := 0.62
@export_range(0.0, 1.0) var leg_linear_assist := 0.6

@export_group("Feedforward")
@export var max_ff_angular_speed := 40.0
@export var feedforward_smoothing_hz := 30.0
@export var body_velocity_smoothing := 6.0

@export_range(0.0, 1.0) var feedforward := 1.0
@export_range(0.0, 1.0) var lower_body_feedforward := 0.0
@export_range(0.0, 1.0) var foot_feedforward := 1.0
@export_range(0.0, 1.0) var leg_feedforward := 0.0

@export_group("Upper Body")
@export var upper_body_stiffness_scale := 10.0

@export var arm_angular_frequency_hz := 18.0
@export var arm_angular_damping_ratio := 1.0

@export_range(0.0, 1.0) var arm_linear_assist := 1.0
@export_range(0.0, 1.0) var torso_linear_assist := 1.0

@export_group("Upright")
@export var upright_torque: float = 2800.0
@export var upright_damping: float = 34.0

@export var spine_upright_torque: float = 0.0
@export var spine_upright_damping: float = 24.0

@export_group("Joint Limits")
@export var override_joint_limits := true
@export var spine_limits := Vector3(65.0, 35.0, 65.0)
@export var head_limits := Vector3(75.0, 60.0, 60.0)
@export var shoulder_limits := Vector3(175.0, 150.0, 175.0)
@export var wrist_limits := Vector3(170.0, 110.0, 170.0)
@export var hip_limits := Vector3(135.0, 45.0, 135.0)
@export var ankle_limits := Vector3(115.0, 115.0, 115.0)

@export var free_shoulders := true
@export var mirror_left_elbow := true

@export_group("Collapse")
@export var upper_collapse_delay := 0.12

@export var corpse_friction := 0.7

@export_group("Hits")
@export var kick_ramp := 0.18

@export var kick_gain := 4.0
@export var max_kick_speed := 5.0
@export var max_kick_spin := 35.0

@export var corpse_hit_speed := 8.0
@export var corpse_hit_scale := 6.0
@export var soak_per_hit := 0.0
@export var soak_fade := 4.0

@export var flinch_attack := 0.1

@export var corpse_hip_flexion := 75.0
@export var corpse_hip_extension := 25.0
@export var corpse_hip_swing := 25.0
@export var corpse_knee_flexion := 115.0
@export var corpse_spine_limits := Vector3(20.0, 15.0, 20.0)
@export var corpse_head_limits := Vector3(30.0, 25.0, 25.0)

@export var corpse_arm_reach := 70.0
@export var arm_return_rate := 14.0

@export var arms_ignore_body := true

@export_group("Killing blow")
@export var launch_speed := 2.5
@export var launch_release := 0.05

@export var throw_ramp := 0.1
@export_range(0.0, 1.0) var throw_leg_share := 0.6

@export_group("Gravity")
@export_range(0.0, 1.0) var gravity_compensation := 0.0

@export_group("Refs")
@export var character: CharacterMovement
@export var animated_skeleton_path: NodePath

@export var gait: GaitDriver
@export var hips_bone_name: StringName = &"mixamorig7_Hips"

@onready var animated_skeleton: Skeleton3D = get_node(animated_skeleton_path)

class Push:
	var bone: PhysicalBone3D
	var speed := Vector3.ZERO
	var spin := Vector3.ZERO
	var age := 0.0


var hips: PhysicalBone3D
var chest: PhysicalBone3D
var _forearm_of := { }

var feet_bones: Array[PhysicalBone3D] = []
var leg_bones: Array[PhysicalBone3D] = []

var spine_bones: Array[PhysicalBone3D] = []
var arm_bones: Array[PhysicalBone3D] = []

var bone_indices: Dictionary = { }
var physical_bones: Array[PhysicalBone3D] = []

var _ang_k := 0.0
var _ang_c := 0.0

var _lin_k := 0.0
var _lin_c := 0.0

var _foot_k := 0.0
var _foot_c := 0.0

var _spine_ang_k := 0.0
var _spine_ang_c := 0.0

var _arm_ang_k := 0.0
var _arm_ang_c := 0.0

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

var _ff_prev_q: Dictionary = { }
var _ff_prev_o: Dictionary = { }

var _ff_ang: Dictionary = { }
var _ff_lin: Dictionary = { }

var _body_v := Vector3.ZERO

var _collapse := -1.0
var _legs_time := 0.0
var _upper_time := 0.0
var _legs_s := 1.0
var _lin_upper_s := 1.0
var _ang_upper_s := 1.0
var _rest_mass := { }
var _flinch := { }
var _pushes: Array[Push] = []
var _blows: Array = []
var _soak := 0.0
var _throw := Vector3.ZERO
var _throw_spin := 0.0
var _throw_age := -1.0
var _delay := 0.0
var _down := false
var _still := 0.0


func _ready() -> void:
	_recompute_constants()

	animated_skeleton.skeleton_updated.connect(_on_animated_skeleton_updated)

	await get_tree().physics_frame

	for child in get_children():
		if child is PhysicalBone3D:
			physical_bones.append(child)

			bone_indices[child] = animated_skeleton.find_bone(child.bone_name)

			var bn := String(child.bone_name)
			if bn == String(hips_bone_name):
				hips = child
			elif "Foot" in bn:
				feet_bones.append(child)
			elif "Leg" in bn:
				leg_bones.append(child)
			elif "Spine" in bn or "Chest" in bn or "Neck" in bn or "Head" in bn:
				spine_bones.append(child)
			elif "Arm" in bn or "Hand" in bn:
				arm_bones.append(child)

	for b in physical_bones:
		var part := String(b.bone_name)
		if part.ends_with("Spine1"):
			chest = b
		elif _is_shoulder(part):
			for other in physical_bones:
				if String(other.bone_name) == part.replace("Arm", "ForeArm"):
					_forearm_of[b] = other

	for b in physical_bones:
		b.gravity_scale = 1.0 - gravity_compensation

		b.mass *= _mass_scale(String(b.bone_name))
		_rest_mass[b] = b.mass

	if override_joint_limits:
		_apply_joint_limits()

	_publish_hinge_axes()

	if arms_ignore_body:
		for arm in arm_bones:
			var side := "Left" if "Left" in String(arm.bone_name) else "Right"
			for other in physical_bones:
				var same_arm := other in arm_bones and side in String(other.bone_name)
				if other != arm and not same_arm:
					arm.add_collision_exception_with(other)

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
	for i in 3:
		await get_tree().physics_frame

	for bone in physical_bones:
		bone.global_transform = _target_body_transform(bone)

	active = true
	physical_bones_start_simulation()


func collapse(legs_time: float, upper_time: float, throw := Vector3.ZERO, spin := 0.0) -> void:
	var launch := clampf(throw.length() / launch_speed, 0.0, 1.0)
	_legs_time = maxf(lerpf(legs_time, launch_release, launch), 0.001)
	_upper_time = maxf(lerpf(upper_time, launch_release, launch), 0.001)
	_delay = lerpf(upper_collapse_delay, 0.0, launch)
	_collapse = 0.0

	_throw = throw
	_throw_spin = spin
	_throw_age = 0.0
	set_physics_process(true)

	for b in physical_bones:
		b.collision_layer = CORPSE_LAYER
		b.collision_mask = 1 | CORPSE_LAYER
		b.axis_lock_linear_z = true
		b.friction = corpse_friction

	_apply_corpse_limits()


func kick(bone: PhysicalBone3D, impulse: Vector3, offset: Vector3) -> void:
	_still = 0.0
	set_physics_process(true)

	var soaked := 1.0 / (1.0 + _soak)
	_soak += soak_per_hit

	if _down:
		var raw := impulse.length() / bone.mass
		var fraction := corpse_hit_speed * (1.0 - exp(-raw / corpse_hit_scale)) / maxf(raw, 0.001)
		_blows.append([bone, impulse * fraction * soaked, offset])
		return

	var push := Push.new()
	push.bone = bone
	push.speed = (impulse * kick_gain * soaked / bone.mass).limit_length(max_kick_speed)
	push.spin = (offset.cross(impulse) * kick_gain * soaked / (bone.mass * 0.015)).limit_length(max_kick_spin)
	_pushes.append(push)


func twist(bone: PhysicalBone3D, spin: Vector3) -> void:
	var push := Push.new()
	push.bone = bone
	push.spin = spin
	_pushes.append(push)
	set_physics_process(true)
	_still = 0.0


func _apply_kicks() -> void:
	_soak = maxf(_soak - soak_fade * get_physics_process_delta_time(), 0.0)

	for blow in _blows:
		(blow[0] as PhysicalBone3D).apply_impulse(blow[1], blow[2])

	_blows.clear()

	var dt := get_physics_process_delta_time()
	var ramp := maxf(kick_ramp, 0.001)
	var left: Array[Push] = []
	for push in _pushes:
		var share := -smoothstep(0.0, ramp, push.age)
		push.age += dt
		share += smoothstep(0.0, ramp, push.age)

		push.bone.linear_velocity += push.speed * share
		push.bone.angular_velocity += push.spin * share
		if push.age < ramp:
			left.append(push)

	_pushes = left
	_apply_throw(dt)


func _apply_throw(dt: float) -> void:
	if _throw_age < 0.0:
		return

	var ramp := maxf(throw_ramp, 0.001)
	var share := -smoothstep(0.0, ramp, _throw_age)
	_throw_age += dt
	share += smoothstep(0.0, ramp, _throw_age)

	for b in physical_bones:
		var weight := 1.0
		if b == hips:
			weight = lerpf(1.0, throw_leg_share, 0.5)
		elif _is_leg(b):
			weight = throw_leg_share

		b.linear_velocity += _throw * weight * share

		var part := String(b.bone_name)
		if part.ends_with("Spine1") or part.ends_with("Head") or b == hips:
			var turn := _throw_spin * (0.4 if b == hips else 1.0)
			b.angular_velocity += Vector3.BACK * turn * share

	if _throw_age >= ramp:
		_throw_age = -1.0


func _is_leg(bone: PhysicalBone3D) -> bool:
	return bone in leg_bones or bone in feet_bones


func flinch(bone: PhysicalBone3D, time: float, grip: float) -> void:
	if _flinch.has(bone):
		var f: Array = _flinch[bone]
		f[0] = maxf(f[0], time)
		f[1] = maxf(f[1], time)
		f[2] = minf(f[2], grip)
	else:
		_flinch[bone] = [time, time, grip, 0.0]


func _update_flinch(delta: float) -> void:
	for bone in _flinch.keys():
		var f: Array = _flinch[bone]
		f[0] -= delta
		if f[0] <= 0.0:
			_flinch.erase(bone)
			continue

		var hold := smoothstep(0.0, 1.0, f[0] / f[1])
		if hold > f[3]:
			f[3] = move_toward(f[3], hold, delta / maxf(flinch_attack, 0.001))
		else:
			f[3] = hold


func _apply_corpse_limits() -> void:
	for b in physical_bones:
		if b.joint_type == PhysicalBone3D.JOINT_TYPE_HINGE and String(b.bone_name).ends_with("Leg"):
			var lower: float = b.get("joint_constraints/angular_limit_lower")
			var upper: float = b.get("joint_constraints/angular_limit_upper")
			if absf(lower) > absf(upper):
				b.set("joint_constraints/angular_limit_lower", -corpse_knee_flexion)
			else:
				b.set("joint_constraints/angular_limit_upper", corpse_knee_flexion)

		if b.joint_type != PhysicalBone3D.JOINT_TYPE_6DOF:
			continue

		var part := String(b.bone_name)
		if part.ends_with("UpLeg"):
			b.set("joint_constraints/x/angular_limit_lower", -corpse_hip_extension)
			b.set("joint_constraints/x/angular_limit_upper", corpse_hip_flexion)
			for axis in ["y", "z"]:
				b.set("joint_constraints/%s/angular_limit_upper" % axis, corpse_hip_swing)
				b.set("joint_constraints/%s/angular_limit_lower" % axis, -corpse_hip_swing)
		elif "Spine" in part:
			_limit_symmetric(b, corpse_spine_limits)
		elif "Head" in part or "Neck" in part:
			_limit_symmetric(b, corpse_head_limits)


func _limit_symmetric(b: PhysicalBone3D, limits: Vector3) -> void:
	var axes := ["x", "y", "z"]
	for i in 3:
		b.set("joint_constraints/%s/angular_limit_upper" % axes[i], limits[i])
		b.set("joint_constraints/%s/angular_limit_lower" % axes[i], -limits[i])


func _update_collapse(delta: float) -> void:
	if _collapse < 0.0:
		return

	_collapse += delta
	var late := _collapse - _delay
	_legs_s = 1.0 - smoothstep(0.0, _legs_time, _collapse)
	_lin_upper_s = 1.0 - smoothstep(0.0, _legs_time, late)
	_ang_upper_s = 1.0 - smoothstep(0.0, _upper_time, late)

	for b in physical_bones:
		var heft := _mass_scale(String(b.bone_name))
		if heft != 1.0:
			b.mass = (_rest_mass[b] as float) * lerpf(1.0 / heft, 1.0, _legs_s)

	if _collapse > _delay + maxf(_legs_time, _upper_time):
		_down = true


func _strength(bone: PhysicalBone3D, linear: bool) -> float:
	var slack := 1.0
	if _flinch.has(bone):
		var f: Array = _flinch[bone]
		slack = lerpf(1.0, f[2], f[3])

	return slack * _collapse_strength(bone, linear)


func _collapse_strength(bone: PhysicalBone3D, linear: bool) -> float:
	if _collapse < 0.0:
		return 1.0

	if bone == hips or bone in leg_bones or bone in feet_bones:
		return _legs_s

	if linear or bone in arm_bones:
		return _lin_upper_s

	return _ang_upper_s


func _mass_scale(bone_name: String) -> float:
	if bone_name.ends_with("UpLeg"):
		return upper_leg_mass_scale

	if bone_name.ends_with("Leg"):
		return lower_leg_mass_scale

	if bone_name.ends_with("Foot"):
		return foot_mass_scale

	return 1.0


func _limits_for(bone_name: String) -> Vector3:
	if "UpLeg" in bone_name:
		return hip_limits

	if "Foot" in bone_name:
		return ankle_limits

	if "Hand" in bone_name:
		return wrist_limits

	if "Arm" in bone_name and "ForeArm" not in bone_name:
		return shoulder_limits

	if "Head" in bone_name or "Neck" in bone_name:
		return head_limits

	if "Spine" in bone_name:
		return spine_limits

	return Vector3.ZERO


func _is_shoulder(bone_name: String) -> bool:
	return "Arm" in bone_name and "ForeArm" not in bone_name


func _is_left_forearm(bone_name: String) -> bool:
	return "Left" in bone_name and "ForeArm" in bone_name


func _apply_joint_limits() -> void:
	for b in physical_bones:
		if mirror_left_elbow and b.joint_type == PhysicalBone3D.JOINT_TYPE_HINGE:
			if _is_left_forearm(String(b.bone_name)):
				var lower: float = b.get("joint_constraints/angular_limit_lower")
				var upper: float = b.get("joint_constraints/angular_limit_upper")
				b.set("joint_constraints/angular_limit_lower", -upper)
				b.set("joint_constraints/angular_limit_upper", -lower)

		if b.joint_type != PhysicalBone3D.JOINT_TYPE_6DOF:
			continue

		var lim := _limits_for(String(b.bone_name))
		if lim == Vector3.ZERO:
			continue

		var free := free_shoulders and _is_shoulder(String(b.bone_name))
		var axes := ["x", "y", "z"]
		for i in 3:
			var deg: float = lim[i]
			b.set("joint_constraints/%s/angular_limit_enabled" % axes[i], not free)
			b.set("joint_constraints/%s/angular_limit_upper" % axes[i], deg)
			b.set("joint_constraints/%s/angular_limit_lower" % axes[i], -deg)


func _publish_hinge_axes() -> void:
	for b in physical_bones:
		if b.joint_type != PhysicalBone3D.JOINT_TYPE_HINGE:
			continue

		var axis_body := b.joint_offset.basis * Vector3.BACK
		var axis_bone := (b.body_offset.basis * axis_body).normalized()

		var lower: float = b.get("joint_constraints/angular_limit_lower")
		var upper: float = b.get("joint_constraints/angular_limit_upper")
		var flexion_axis := -axis_bone if upper + lower >= 0.0 else axis_bone

		animated_skeleton.set_meta(StringName("hinge_axis_" + String(b.bone_name)), flexion_axis)


func _gains(freq_hz: float, ratio: float) -> Vector2:
	var wn := TAU * freq_hz
	var step := 1.0 / maxf(float(Engine.physics_ticks_per_second), 1.0)

	wn = minf(wn, max_gain_per_step / step)
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

	g = _gains(arm_angular_frequency_hz, arm_angular_damping_ratio)
	_arm_ang_k = g.x
	_arm_ang_c = g.y

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
	return lerpf(1.0, landing_leg_softness, gait.landing_amount)


func _bone_ang_k(bone: PhysicalBone3D) -> float:
	if bone in spine_bones:
		return _spine_ang_k

	if bone == hips:
		return _hips_ang_k

	if bone in arm_bones:
		return _arm_ang_k

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

	if bone in arm_bones:
		return _arm_ang_c

	var soft := _leg_softness()

	if bone in feet_bones:
		return _foot_ang_c * soft

	if bone in leg_bones:
		return _leg_ang_c * soft

	return _ang_c


func _body_velocity() -> Vector3:
	return _body_v


func _update_body_velocity(delta: float) -> void:
	var v := character.velocity
	if body_velocity_smoothing <= 0.0:
		_body_v = v
	else:
		_body_v = _body_v.lerp(v, 1.0 - exp(-body_velocity_smoothing * delta))


func _limit_arms() -> void:
	var down := (hips.global_position - chest.global_position).normalized()
	var reach := deg_to_rad(corpse_arm_reach)

	for shoulder in _forearm_of:
		var arm: PhysicalBone3D = shoulder
		var dir := ((_forearm_of[arm] as PhysicalBone3D).global_position - arm.global_position).normalized()
		var excess := dir.angle_to(down) - reach
		if excess <= 0.0:
			continue

		var axis := dir.cross(down)
		if axis.length_squared() < 0.000001:
			continue

		axis = axis.normalized()
		var want := excess * arm_return_rate
		var along := arm.angular_velocity.dot(axis)
		if along < want:
			arm.angular_velocity += axis * (want - along)


func _corpse_step(delta: float) -> void:
	_limit_arms()
	_apply_kicks()

	var moving := not _pushes.is_empty() or _throw_age >= 0.0
	for b in physical_bones:
		if b.linear_velocity.length_squared() > 0.01 or b.angular_velocity.length_squared() > 0.04:
			moving = true
			break

	_still = 0.0 if moving else _still + delta
	if _still > 0.6:
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	if _down:
		_corpse_step(delta)
		return

	_update_body_velocity(delta)
	_update_flinch(delta)
	_update_collapse(delta)

	for bone in physical_bones:
		var target := _target_body_transform(bone)

		_update_feedforward(bone, target, delta)
		_apply_angular_track(bone, target, delta)

		if bone == hips:
			_track_linear(bone, target, _lin_k, _lin_c, 1.0, delta)
			_apply_upright_torque(bone, delta, upright_torque * _strength(bone, true), upright_damping)
		elif bone in spine_bones:
			if spine_upright_torque > 0.0:
				_apply_upright_torque(bone, delta, spine_upright_torque, spine_upright_damping)

			if torso_linear_assist > 0.0:
				_track_linear(
					bone,
					target,
					_lin_k,
					_lin_c,
					torso_linear_assist,
					delta,
					max_leg_track_speed,
				)
		elif bone in arm_bones:
			if arm_linear_assist > 0.0:
				_track_linear(
					bone,
					target,
					_lin_k,
					_lin_c,
					arm_linear_assist,
					delta,
					max_leg_track_speed,
				)
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
					leg_linear_assist * _leg_softness(),
					delta,
					max_leg_track_speed,
				)

	if _collapse >= 0.0:
		_limit_arms()

	_apply_kicks()


func _feedforward_for(bone: PhysicalBone3D) -> float:
	if bone in arm_bones or bone.bone_name.ends_with("Head"):
		return feedforward

	if bone in feet_bones:
		return foot_feedforward

	if bone in leg_bones:
		return leg_feedforward

	return lower_body_feedforward


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
		_ff_lin[bone] = _body_velocity()

	_ff_prev_q[bone] = q
	_ff_prev_o[bone] = o


func _apply_angular_track(bone: PhysicalBone3D, target: Transform3D, delta: float) -> void:
	var s := _strength(bone, false)
	var k := _bone_ang_k(bone) * s * s
	var c := _bone_ang_c(bone) * s
	var ff: Vector3 = (_ff_ang[bone] as Vector3) * _feedforward_for(bone)

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
	assist *= _strength(bone, true)

	var body_v := _body_velocity()
	var ff_v: Vector3 = _ff_lin[bone]

	var target_v := body_v.lerp(ff_v, _feedforward_for(bone))
	var rel_v := bone.linear_velocity - target_v

	var pos_error: Vector3 = target.origin - bone.global_position
	rel_v = (rel_v + pos_error * k * delta) / (1.0 + c * delta)

	if max_rel < INF:
		rel_v = rel_v.limit_length(max_rel)

	bone.linear_velocity = bone.linear_velocity.lerp(rel_v + target_v, assist)


func _upright_reference() -> Vector3:
	if absf(gait.lean_angle) > 0.001 and gait.lean_axis.length_squared() > 0.0001:
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


func _target_body_transform(bone: PhysicalBone3D) -> Transform3D:
	var idx: int = bone_indices[bone]
	return _anim_xform * _anim_poses[idx] * bone.body_offset


func _on_animated_skeleton_updated() -> void:
	if not animated_skeleton.is_inside_tree():
		return

	var n := animated_skeleton.get_bone_count()
	_anim_poses.resize(n)

	for i in n:
		_anim_poses[i] = animated_skeleton.get_bone_global_pose(i)

	_anim_xform = animated_skeleton.global_transform
