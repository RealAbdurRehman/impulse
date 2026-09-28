extends Node3D
class_name ActiveRagdollController

@export var skeleton: Skeleton3D
@export var simulator: PhysicalBoneSimulator3D
@export var hips_bone_name := "mixamorig7_Hips"

@export_group("Pose Holding")
@export var pose_stiffness := 25.0
@export var pose_damping := 10.0
@export var max_torque := 18.0

@export_group("Upright")
@export var upright_stiffness := 120.0
@export var upright_damping := 20.0

@export_group("Standing Height")
@export var target_standing_height := 1.0
@export var height_stiffness := 4.0
@export var height_damping := 10.0
@export var max_support_acceleration := 12.0
@export var ground_mask := 1

@export_group("State")
@export var is_alive := true

const CORE_BONES := [
	&"mixamorig7_Hips",
	&"mixamorig7_Spine",
	&"mixamorig7_Spine1",
	&"mixamorig7_Spine2",
	&"mixamorig7_Neck",
	&"mixamorig7_Head",
	&"mixamorig7_LeftUpLeg",
	&"mixamorig7_LeftLeg",
	&"mixamorig7_LeftFoot",
	&"mixamorig7_LeftToeBase",
	&"mixamorig7_RightUpLeg",
	&"mixamorig7_RightLeg",
	&"mixamorig7_RightFoot",
	&"mixamorig7_RightToeBase",
	&"mixamorig7_LeftShoulder",
	&"mixamorig7_LeftArm",
	&"mixamorig7_LeftForeArm",
	&"mixamorig7_LeftHand",
	&"mixamorig7_RightShoulder",
	&"mixamorig7_RightArm",
	&"mixamorig7_RightForeArm",
	&"mixamorig7_RightHand",
]

const BONE_WEIGHTS := {
	"ToeBase": 0.10,
	"Foot": 0.30,
	"UpLeg": 1.00,
	"Leg": 0.70,
	"Spine2": 1.40,
	"Spine1": 1.30,
	"Spine": 1.20,
	"Hips": 2.00,
	"Head": 0.40,
	"Neck": 0.50,
	"Shoulder": 0.30,
	"ForeArm": 0.20,
	"Arm": 0.25,
	"Hand": 0.08,
}

var is_initialized := false
var center_of_mass := Vector3.ZERO

var _hips: ActivePhysicalBone
var _hips_up_axis_local := Vector3.UP
var _bone_targets := { }
var _bone_weights := { }
var _all_bones: Array[ActivePhysicalBone] = []
var _excluded_rids: Array[RID] = []
var _total_mass := 1.0


func _ready() -> void:
	if skeleton == null:
		skeleton = get_node_or_null("../Model/Armature/Skeleton3D") as Skeleton3D

	if simulator == null:
		simulator = get_node_or_null("../Model/Armature/Skeleton3D/PhysicalBoneSimulator3D") as PhysicalBoneSimulator3D

	if simulator == null:
		push_error("ActiveRagdollController: simulator is not assigned.")
		return

	for child in simulator.get_children():
		if child is ActivePhysicalBone:
			var bone := child as ActivePhysicalBone
			if CORE_BONES.has(bone.bone_name):
				bone.gravity_scale = 0.0
				bone.linear_velocity = Vector3.ZERO
				bone.angular_velocity = Vector3.ZERO

	simulator.physical_bones_start_simulation(CORE_BONES)
	await get_tree().physics_frame

	_cache_bone_data()

	_hips = simulator.get_node_or_null("Physical Bone " + hips_bone_name) as ActivePhysicalBone

	if _hips == null:
		push_error("ActiveRagdollController: hips bone was not found.")
		return

	_hips_up_axis_local = (
		_hips.global_transform.basis.orthonormalized().inverse() * Vector3.UP
	).normalized()

	for bone in _all_bones:
		bone.linear_velocity = Vector3.ZERO
		bone.angular_velocity = Vector3.ZERO
		bone.gravity_scale = 1.0

	is_initialized = true


func _physics_process(_delta: float) -> void:
	if not is_initialized or not is_alive:
		return

	_update_center_of_mass()
	_apply_pose_holding()

	# Add back later
	#_apply_upright_torque()
	_apply_ground_support()


func _cache_bone_data() -> void:
	_all_bones.clear()
	_excluded_rids.clear()
	_bone_targets.clear()
	_bone_weights.clear()
	_total_mass = 0.0

	for child in simulator.get_children():
		if child is not ActivePhysicalBone:
			continue

		var bone := child as ActivePhysicalBone
		if not CORE_BONES.has(bone.bone_name):
			continue

		_all_bones.append(bone)
		_excluded_rids.append(bone.get_rid())
		_total_mass += bone.mass

		_bone_targets[bone] = bone \
				.global_transform \
				.basis \
				.orthonormalized() \
				.get_rotation_quaternion()

		var weight := 0.05
		for key in BONE_WEIGHTS:
			if bone.bone_name.contains(key):
				weight = BONE_WEIGHTS[key]
				break
		_bone_weights[bone] = weight

	_total_mass = maxf(_total_mass, 1.0)


func _update_center_of_mass() -> void:
	var total := 0.0
	var weighted_position := Vector3.ZERO

	for bone in _all_bones:
		total += bone.mass
		weighted_position += bone.global_position * bone.mass

	if total > 0.0:
		center_of_mass = weighted_position / total


func _apply_pose_holding() -> void:
	for bone in _all_bones:
		var target_rotation: Quaternion = _bone_targets[bone]
		var current_rotation := bone \
				.global_transform \
				.basis \
				.orthonormalized() \
				.get_rotation_quaternion()

		var error := target_rotation * current_rotation.inverse()
		if error.w < 0.0:
			error = -error

		var angle := error.get_angle()
		if angle < 0.001:
			continue

		var weight: float = _bone_weights[bone]
		var torque := (
			error.get_axis() * angle * pose_stiffness * weight
			- bone.angular_velocity * pose_damping * weight
		)

		bone.request_torque(torque.limit_length(max_torque * maxf(weight, 0.1)))


func _apply_upright_torque() -> void:
	var current_up := (
		_hips.global_transform.basis.orthonormalized() * _hips_up_axis_local
	).normalized()

	var axis := current_up.cross(Vector3.UP)
	var axis_length := axis.length()
	if axis_length < 0.0001:
		return

	var angle := acos(clampf(current_up.dot(Vector3.UP), -1.0, 1.0))
	var torque := (
		axis / axis_length * angle * upright_stiffness - _hips.angular_velocity * upright_damping
	)

	_hips.request_torque(torque.limit_length(max_torque * 3.0))


func _apply_ground_support() -> void:
	var ray := PhysicsRayQueryParameters3D.new()
	ray.from = _hips.global_position + Vector3.UP * 0.1
	ray.to = _hips.global_position - Vector3.UP * 4.0
	ray.collision_mask = ground_mask
	ray.exclude = _excluded_rids

	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		return

	var current_height: float = _hips.global_position.y - hit.position.y
	var height_error := target_standing_height - current_height
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))

	var support_acceleration := gravity + height_error * height_stiffness
	support_acceleration -= _hips.linear_velocity.y * height_damping
	support_acceleration = clampf(
		support_acceleration,
		-max_support_acceleration,
		max_support_acceleration,
	)

	_hips.request_force(Vector3.UP * support_acceleration * _total_mass)


func trigger_death(impact_impulse := Vector3.ZERO, hit_bone_name := "") -> void:
	is_alive = false

	if hit_bone_name.is_empty() or simulator == null:
		return

	var bone := simulator.get_node_or_null(hit_bone_name) as PhysicalBone3D
	if bone:
		bone.apply_impulse(impact_impulse)
