extends PhysicalBoneSimulator3D

@export_group("Tracking")
@export var angular_frequency_hz := 6.5
@export var angular_damping_ratio := 1.15

@export var linear_frequency_hz := 6.0
@export var linear_damping_ratio := 1.15

@export var foot_linear_assist: float = 0.7
@export var foot_linear_frequency_hz := 8.0
@export var foot_linear_damping_ratio := 1.1

@export_group("Upper Body")
@export var upper_body_stiffness_scale := 10.0

@export_group("Upright")
@export var upright_torque: float = 2600.0
@export var upright_damping: float = 34.0

@export var spine_upright_torque: float = 1400.0
@export var spine_upright_damping: float = 24.0

@export_group("Gravity")
@export_range(0.0, 1.0) var gravity_compensation := 0.0

@export_group("Refs")
@export var animated_skeleton_path: NodePath
@export var player_body: CharacterBody3D
@export var hips_bone_name: StringName = &"mixamorig7_Hips"
@export var run_speed: float = 3.2

@onready var physics_skeleton: Skeleton3D = get_parent()
@onready var animated_skeleton: Skeleton3D = get_node(animated_skeleton_path)

var hips: PhysicalBone3D
var feet_bones: Array[PhysicalBone3D] = []
var spine_bones: Array[PhysicalBone3D] = []
var bone_indices: Dictionary = { }
var physical_bones: Array[PhysicalBone3D] = []

var velocity: Vector3 = Vector3.ZERO
var desired_speed := 0.0

var _ang_k := 0.0
var _ang_c := 0.0
var _lin_k := 0.0
var _lin_c := 0.0
var _foot_k := 0.0
var _foot_c := 0.0
var _spine_ang_k := 0.0
var _spine_ang_c := 0.0

var _anim_poses: Array[Transform3D] = []
var _anim_xform := Transform3D.IDENTITY
var _on_floor := true
var _prev_hips_pos := Vector3.ZERO
var _hips_vel_smooth := Vector3.ZERO


func _ready() -> void:
	_recompute_constants()

	animated_skeleton.skeleton_updated.connect(_on_animated_skeleton_updated)

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
			elif "Spine" in bn or "Chest" in bn or "Neck" in bn or "Head" in bn:
				spine_bones.append(child)

	for b in physical_bones:
		b.gravity_scale = 1.0 - gravity_compensation

	await get_tree().process_frame
	for bone in physical_bones:
		if bone_indices.has(bone):
			bone.global_transform = _target_body_transform(bone)

	if hips:
		_prev_hips_pos = hips.global_position

	active = true
	physical_bones_start_simulation()


func _recompute_constants() -> void:
	var wn_a := TAU * angular_frequency_hz
	_ang_k = wn_a * wn_a
	_ang_c = 2.0 * angular_damping_ratio * wn_a

	var wn_l := TAU * linear_frequency_hz
	_lin_k = wn_l * wn_l
	_lin_c = 2.0 * linear_damping_ratio * wn_l

	var wn_f := TAU * foot_linear_frequency_hz
	_foot_k = wn_f * wn_f
	_foot_c = 2.0 * foot_linear_damping_ratio * wn_f

	var wn_s := TAU * angular_frequency_hz * upper_body_stiffness_scale
	_spine_ang_k = wn_s * wn_s
	_spine_ang_c = 2.0 * angular_damping_ratio * wn_s


func _bone_ang_k(bone: PhysicalBone3D) -> float:
	if bone in spine_bones:
		return _spine_ang_k
	return _ang_k


func _bone_ang_c(bone: PhysicalBone3D) -> float:
	if bone in spine_bones:
		return _spine_ang_c
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
		_apply_angular_track(bone, target, delta)

		if bone == hips:
			_apply_hips_linear(bone, target, delta)
			_apply_upright_torque(bone, delta, upright_torque, upright_damping)
		elif bone in spine_bones:
			_apply_upright_torque(bone, delta, spine_upright_torque, spine_upright_damping)
		elif bone in feet_bones and foot_linear_assist > 0.0:
			_apply_foot_linear(bone, target, delta)


func _apply_angular_track(bone: PhysicalBone3D, target: Transform3D, delta: float) -> void:
	var k := _bone_ang_k(bone)
	var c := _bone_ang_c(bone)

	var current_q := bone.global_transform.basis.get_rotation_quaternion()
	var target_q := target.basis.get_rotation_quaternion()

	var diff := target_q * current_q.inverse()
	if diff.w < 0.0:
		diff = -diff

	var err := diff.get_axis() * diff.get_angle()

	bone.angular_velocity = (bone.angular_velocity + err * k * delta) \
			/ (1.0 + c * delta)


func _apply_hips_linear(bone: PhysicalBone3D, target: Transform3D, delta: float) -> void:
	var target_v := player_body.velocity if player_body else Vector3.ZERO
	var rel_v := bone.linear_velocity - target_v

	var pos_error: Vector3 = target.origin - bone.global_position
	rel_v = (rel_v + pos_error * _lin_k * delta) / (1.0 + _lin_c * delta)

	bone.linear_velocity = rel_v + target_v


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

	var axis := up.cross(Vector3.UP)
	if axis.length_squared() < 0.000001:
		return
	axis = axis.normalized()

	var angle := up.signed_angle_to(Vector3.UP, axis)
	var correction := axis * angle * strength
	correction -= bone.angular_velocity * damping

	bone.angular_velocity += correction * delta


func _apply_foot_linear(bone: PhysicalBone3D, target: Transform3D, delta: float) -> void:
	var target_v := player_body.velocity if player_body else Vector3.ZERO
	var rel_v := bone.linear_velocity - target_v

	var pos_error: Vector3 = target.origin - bone.global_position
	rel_v = (rel_v + pos_error * _foot_k * delta) / (1.0 + _foot_c * delta)

	bone.linear_velocity = rel_v + target_v


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
