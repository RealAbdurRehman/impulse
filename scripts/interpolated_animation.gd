extends Skeleton3D

@export var physics_skeleton_path: NodePath = "../../../PhysicsSkeleton/Skeleton3D"

@export var follow_speed: float = 30.0

@onready var physics_skeleton: Skeleton3D = get_node(physics_skeleton_path)


func _process(delta: float) -> void:
	var t := 1.0 - exp(-follow_speed * delta)
	var to_skeleton_space := global_transform.affine_inverse() * physics_skeleton.global_transform

	for i in get_bone_count():
		var target: Transform3D = to_skeleton_space * physics_skeleton.get_bone_global_pose(i)

		set_bone_global_pose(i, get_bone_global_pose(i).interpolate_with(target, t))
