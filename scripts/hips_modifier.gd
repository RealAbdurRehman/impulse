extends SkeletonModifier3D
class_name HipsModifier

@export var gait: Node
@export var hips_bone: StringName = &"mixamorig7_Hips"
@export var left_upleg_bone: StringName = &"mixamorig7_LeftUpLeg"
@export var left_leg_bone: StringName = &"mixamorig7_LeftLeg"
@export var left_foot_bone: StringName = &"mixamorig7_LeftFoot"

@export var reset_pose_each_frame := true
@export var measure_rig := true

var _hips_idx := -1
var _measured := false


func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null or gait == null:
		return

	if _hips_idx == -1:
		_hips_idx = skel.find_bone(hips_bone)
		if _hips_idx == -1:
			return

	if reset_pose_each_frame:
		skel.reset_bone_poses()

	if measure_rig and not _measured:
		_measure(skel)

	var to_skel := skel.global_transform.basis.inverse()
	var lean: float = gait.lean_angle

	var pose := skel.get_bone_global_pose(_hips_idx)
	var shift_fwd: float = gait.hips_offset_fwd
	var fwd_world: Vector3 = skel.global_transform.basis.orthonormalized() * Vector3.BACK
	pose.origin += to_skel * (Vector3(0.0, gait.hips_offset_y, 0.0) + fwd_world * shift_fwd)

	if absf(lean) > 0.001:
		var axis: Vector3 = (to_skel * (gait.lean_axis as Vector3)).normalized()
		pose.basis = Basis(axis, lean) * pose.basis

	skel.set_bone_global_pose(_hips_idx, pose)


func _measure(skel: Skeleton3D) -> void:
	var up := skel.find_bone(left_upleg_bone)
	var knee := skel.find_bone(left_leg_bone)
	var foot := skel.find_bone(left_foot_bone)

	if up < 0 or knee < 0 or foot < 0:
		_measured = true
		return

	var xf := skel.global_transform
	var a := xf * skel.get_bone_global_rest(up).origin
	var b := xf * skel.get_bone_global_rest(knee).origin
	var c := xf * skel.get_bone_global_rest(foot).origin

	var leg := (a - b).length() + (b - c).length()
	var root_y: float = (gait.player as Node3D).global_position.y

	if leg > 0.2:
		gait.leg_length = leg
		gait.hip_rest_height = a.y - root_y

	_measured = true
