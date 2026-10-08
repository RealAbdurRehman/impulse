extends SkeletonModifier3D
class_name FootModifier

@export var left_foot_target: Node3D
@export var right_foot_target: Node3D

@export var left_foot_bone: StringName = &"mixamorig7_LeftFoot"
@export var right_foot_bone: StringName = &"mixamorig7_RightFoot"

@export_range(0.0, 1.0) var strength := 1.0
@export_range(0.0, 80.0) var max_tilt_degrees := 45.0
@export_range(-45.0, 45.0) var pitch_offset_degrees := 10.0

var _idx: Array[int] = [-1, -1]


func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null:
		return

	_align(skel, 0, left_foot_bone, left_foot_target)
	_align(skel, 1, right_foot_bone, right_foot_target)


func _align(skel: Skeleton3D, slot: int, bone_name: StringName, target: Node3D) -> void:
	if target == null or _idx[slot] == -2:
		return

	if _idx[slot] == -1:
		_idx[slot] = skel.find_bone(bone_name)

		if _idx[slot] == -1:
			_idx[slot] = -2

			return

	var idx := _idx[slot]
	var skel_basis := skel.global_transform.basis.orthonormalized()

	var rest_world := skel_basis * skel.get_bone_global_rest(idx).basis.orthonormalized()

	var ground_up := target.global_transform.basis.y.normalized()

	var tilt := Quaternion(Vector3.UP, ground_up)
	var max_tilt := deg_to_rad(max_tilt_degrees)

	if tilt.get_angle() > max_tilt:
		tilt = Quaternion(tilt.get_axis(), max_tilt)

	var desired := Basis(tilt) * rest_world

	if absf(pitch_offset_degrees) > 0.001:
		var side_axis := target.global_transform.basis.x.normalized()
		desired = Basis(side_axis, deg_to_rad(pitch_offset_degrees)) * desired

	var pose := skel.get_bone_global_pose(idx)
	var current_world := skel_basis * pose.basis.orthonormalized()
	var final_world := current_world.orthonormalized().slerp(desired.orthonormalized(), strength)

	pose.basis = skel_basis.inverse() * final_world
	skel.set_bone_global_pose(idx, pose)
