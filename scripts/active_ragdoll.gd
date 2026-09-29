extends PhysicalBoneSimulator3D

@export var angular_stiffness: float = 2000.0
@export var angular_damping: float = 60.0
@export var linear_stiffness: float = 3500.0
@export var linear_damping: float = 40.0
@export var animated_skeleton_path: NodePath = "../../../AnimatedSkeleton/Skeleton3D"

@onready var physics_skeleton: Skeleton3D = get_parent()
@onready var animated_skeleton: Skeleton3D = get_node(animated_skeleton_path)

var hips: PhysicalBone3D
var bone_indices: Dictionary = { }
var physical_bones: Array[PhysicalBone3D] = []


func _ready() -> void:
	await get_tree().physics_frame

	for child in get_children():
		if child is PhysicalBone3D:
			physical_bones.append(child)

			var idx := animated_skeleton.find_bone(child.bone_name)
			if idx == -1:
				push_warning("No animated bone matches " + child.bone_name)
			else:
				bone_indices[child] = idx

			if child.bone_name == "mixamorig7_Hips":
				hips = child

	await get_tree().process_frame
	for bone in physical_bones:
		if bone_indices.has(bone):
			bone.global_transform = _target_body_transform(bone)

	active = true
	physical_bones_start_simulation()


func _physics_process(delta: float) -> void:
	for bone in physical_bones:
		if not bone_indices.has(bone):
			continue

		var target := _target_body_transform(bone)

		var current_q := bone.global_transform.basis.get_rotation_quaternion()
		var target_q := target.basis.get_rotation_quaternion()

		var diff := target_q * current_q.inverse()
		if diff.w < 0.0:
			diff = -diff

		var torque := diff.get_axis() * diff.get_angle() * angular_stiffness \
				- bone.angular_velocity * angular_damping

		bone.angular_velocity += torque * delta

		if bone == hips:
			var pos_error: Vector3 = target.origin - bone.global_position
			var force := pos_error * linear_stiffness - bone.linear_velocity * linear_damping

			bone.linear_velocity += force * delta


func _target_body_transform(bone: PhysicalBone3D) -> Transform3D:
	var target_bone_global: Transform3D = animated_skeleton.global_transform \
			* animated_skeleton.get_bone_global_pose(bone_indices[bone])

	return target_bone_global * bone.body_offset.affine_inverse()
