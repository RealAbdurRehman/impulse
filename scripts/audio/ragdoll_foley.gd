class_name RagdollFoley
extends Node

const PARTS := {
	&"Hips": 1.0,
	&"Spine2": 1.0,
	&"Head": 0.7,
	&"LeftUpLeg": 0.6,
	&"RightUpLeg": 0.6,
	&"LeftHand": 0.35,
	&"RightHand": 0.35,
}

@export var min_speed := 1.2
@export var min_loss := 1.0
@export var full_loss := 7.0
@export var cooldown := 0.12
@export var probe := 0.45
@export var surface_share := 0.55

var _bones: Array[PhysicalBone3D] = []
var _weights := PackedFloat32Array()
var _velocity: Array[Vector3] = []
var _rest := PackedFloat32Array()


func _ready() -> void:
	for bone in (get_parent() as ActiveRagdoll).physical_bones:
		var part := StringName(String(bone.bone_name).get_slice("_", 1))
		if PARTS.has(part):
			_bones.append(bone)
			_weights.append(PARTS[part])
			_velocity.append(bone.linear_velocity)
			_rest.append(0.0)


func _physics_process(delta: float) -> void:
	for i in _bones.size():
		var bone := _bones[i]
		var now := bone.linear_velocity
		var before := _velocity[i]
		_velocity[i] = now
		_rest[i] = maxf(_rest[i] - delta, 0.0)
		var loss := before.length() - now.length()
		if _rest[i] > 0.0 or before.length() < min_speed or loss < min_loss:
			continue

		_rest[i] = cooldown
		_strike(bone.global_position, before.normalized(), clampf(loss / full_loss, 0.0, 1.0) * _weights[i])


func _strike(at: Vector3, dir: Vector3, level: float) -> void:
	var foley := Foley.of(self)
	foley.thud(at, level)
	var space := (get_parent() as Node3D).get_world_3d().direct_space_state
	var found := space.intersect_ray(PhysicsRayQueryParameters3D.create(at - dir * 0.05, at + dir * probe, 1))
	if not found.is_empty():
		foley.hit(at, Surfaces.of(found.collider), level * surface_share, -3.0)
