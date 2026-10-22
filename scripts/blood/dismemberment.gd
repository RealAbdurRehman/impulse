class_name Dismemberment
extends Node

const TOUGHNESS := {
	&"Head": 85.0,
	&"Arm": 75.0,
	&"ForeArm": 55.0,
	&"Hand": 40.0,
	&"UpLeg": 95.0,
	&"Leg": 65.0,
	&"Foot": 45.0,
}

const THROW := {
	&"Head": 0.45,
	&"Arm": 0.7,
	&"ForeArm": 0.85,
	&"Hand": 1.0,
	&"UpLeg": 0.55,
	&"Leg": 0.7,
	&"Foot": 0.9,
}

@export var enabled := true
@export var toughness := 1.0
@export var corpse_toughness := 0.7
@export var memory := 10.0
@export var launch := Vector2(3.5, 9.0)
@export var gibs_per_damage := 1.0 / 40.0
@export_range(0.2, 1.0) var neck_keep := 0.55

var health: Health
var ragdoll: ActiveRagdoll

var _held := { }
var _need := { }


func _ready() -> void:
	health = get_parent() as Health
	ragdoll = health.ragdoll as ActiveRagdoll
	health.damaged.connect(_on_damaged)
	health.corpse_struck.connect(_on_corpse_struck)


func _on_damaged(amount: float, _point: Vector3, direction: Vector3, bone: PhysicalBone3D) -> void:
	_strike(amount, direction, bone, false)


func _on_corpse_struck(
	amount: float,
	_point: Vector3,
	direction: Vector3,
	bone: PhysicalBone3D,
) -> void:
	_strike(amount, direction, bone, true)


func _strike(amount: float, direction: Vector3, bone: PhysicalBone3D, corpse: bool) -> void:
	if not enabled:
		return

	var part := StumpCap.part_of(bone)
	if part == &"" or not ragdoll.can_sever(bone):
		return

	var now := Time.get_ticks_msec() * 0.001
	var old: Array = _held.get(bone, [0.0, now])
	var damage := maxf(float(old[0]) - memory * (now - float(old[1])), 0.0) + amount
	_held[bone] = [damage, now]

	if not _need.has(bone):
		_need[bone] = float(TOUGHNESS[part]) * randf_range(0.85, 1.25)

	if damage >= float(_need[bone]) * toughness * (corpse_toughness if corpse else 1.0):
		_cut(bone, damage, direction, corpse)


func _cut(bone: PhysicalBone3D, damage: float, direction: Vector3, corpse: bool) -> void:
	var parent := ragdoll.parent_bone(bone)
	var half := bone.global_transform.basis * bone.body_offset.origin
	var near := bone.global_position + half
	var far := bone.global_position - half
	var joint := (
		near
		if near.distance_to(parent.global_position) < far.distance_to(parent.global_position)
		else far
	)
	var reach := (bone.global_position - joint).normalized()
	var radius: float = StumpCap.RADIUS[StumpCap.part_of(bone)]

	var loose := ragdoll.sever(bone)
	if not corpse:
		health.current = 0.0

	if StumpCap.part_of(bone) == &"Head":
		var neck := parent.get_node(^"Neck") as MeshInstance3D
		var cylinder := neck.mesh as CylinderMesh
		var axis := neck.global_transform.basis.y.normalized()
		if axis.dot(reach) < 0.0:
			axis = -axis

		var full_top := neck.global_position + axis * cylinder.height * 0.5
		var base := neck.global_position - axis * cylinder.height * 0.5
		var width := cylinder.top_radius * 0.96
		var seat := StumpCap.seat(bone.get_node(^"Look") as MeshInstance3D, full_top, axis, width)

		neck.scale.y *= neck_keep
		neck.global_position = base + axis * cylinder.height * neck_keep * 0.5
		var top := base + axis * cylinder.height * neck_keep
		StumpCap.attach(parent, top, axis, width)
		StumpCap.attach(bone, seat, -axis, width)
		joint = top
	else:
		StumpCap.attach(parent, joint, reach, radius)
		StumpCap.attach(bone, joint, -reach, radius)

	var dir := Vector3(direction.x, direction.y, 0.0).normalized()
	var speed := lerpf(launch.x, launch.y, clampf(damage / 250.0, 0.0, 1.0)) * float(
		THROW[StumpCap.part_of(bone)]
	)
	var thrown := (dir * 0.75 + reach * 0.5).normalized() * speed + Vector3.UP
	for piece in loose:
		piece.linear_velocity += thrown
		piece.angular_velocity += Vector3.BACK * randf_range(-12.0, 12.0) + Vector3(
			randf_range(-3.0, 3.0),
			randf_range(-3.0, 3.0),
			0.0,
		)

	health.bleeding.stump(parent, bone, joint, reach, damage)
	BloodWorld.of(self).gibs.burst(joint, dir, 3 + int(damage * gibs_per_damage), Vector2(1.5, 5.5))
