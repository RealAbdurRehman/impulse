extends Node3D
#class_name ActiveRagdollIK
#
#@export var controller: ActiveRagdollController
#@export var simulator: PhysicalBoneSimulator3D
#
#@export var left_foot_target: Node3D
#@export var right_foot_target: Node3D
#
#
#@export_group("Foot Spring")
#@export var foot_position_stiffness: float = 400.0
#@export var foot_position_damping: float = 25.0
#@export var max_foot_force: float = 150.0
#
#@export_group("Leg Pull")
#@export var thigh_pull_stiffness: float = 80.0
#@export var thigh_pull_damping: float = 10.0
#
#var _left_foot: ActivePhysicalBone = null
#var _right_foot: ActivePhysicalBone = null
#var _left_thigh: ActivePhysicalBone = null
#var _right_thigh: ActivePhysicalBone = null
#
#
#func _ready() -> void:
#if not simulator:
#return
#_left_foot = simulator.get_node_or_null("Physical Bone mixamorig7_LeftFoot") as ActivePhysicalBone
#_right_foot = simulator.get_node_or_null("Physical Bone mixamorig7_RightFoot") as ActivePhysicalBone
#_left_thigh = simulator.get_node_or_null("Physical Bone mixamorig7_LeftUpLeg") as ActivePhysicalBone
#_right_thigh = simulator.get_node_or_null("Physical Bone mixamorig7_RightUpLeg") as ActivePhysicalBone
#
#
#func _physics_process(delta: float) -> void:
#if not controller or not controller.is_alive:
#return
#
#_drive_foot(_left_foot, left_foot_target, _left_thigh, delta)
#_drive_foot(_right_foot, right_foot_target, _right_thigh, delta)
#
#
#func _drive_foot(
#foot: ActivePhysicalBone,
#target: Node3D,
#thigh: ActivePhysicalBone,
#delta: float,
#) -> void:
#if not foot or not target:
#return
#
#var pos_error := target.global_position - foot.global_position
#var force := pos_error * foot_position_stiffness \
#- foot.linear_velocity * foot_position_damping
#
#force = force.limit_length(max_foot_force)
#foot.apply_central_impulse(force * delta)
#
#if not thigh:
#return
#
#var desired_dir := (target.global_position - thigh.global_position).normalized()
#var current_dir := thigh.global_transform.basis.y
#
#var cross := current_dir.cross(desired_dir)
#var torque := cross * thigh_pull_stiffness - thigh.angular_velocity * thigh_pull_damping
#
#torque = torque.limit_length(thigh_pull_stiffness * 0.5)
#thigh.request_torque(torque)
