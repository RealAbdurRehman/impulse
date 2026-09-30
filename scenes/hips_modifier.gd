extends SkeletonModifier3D

class_name HipsModifier

@export var gait: Node
@export var hips_bone: StringName = &"mixamorig7_Hips"

var _hips_idx := -1


func _process_modification() -> void:
	var skel := get_skeleton()

	if skel == null or gait == null:
		return

	if _hips_idx == -1:
		_hips_idx = skel.find_bone(hips_bone)

		if _hips_idx == -1:
			push_warning("hips_modifier: bone not found: " + str(hips_bone))

			return

	var pose := skel.get_bone_global_pose(_hips_idx)
	var to_skel := skel.global_transform.basis.inverse()

	pose.origin += to_skel * Vector3(0.0, gait.hips_offset_y, 0.0)

	if absf(gait.lean_angle) > 0.001:
		var axis: Vector3 = (to_skel * gait.lean_axis).normalized()
		pose.basis = Basis(axis, gait.lean_angle) * pose.basis

	skel.set_bone_global_pose(_hips_idx, pose)
