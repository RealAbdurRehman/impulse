class_name HitStagger
extends Node

@export var health: Health
@export var movement: CharacterMovement
@export var ragdoll: ActiveRagdoll
@export var spine: SpineModifier

@export_group("Step back")
## Added per 25 damage, decays on its own; limit is the most it can build up to.
@export var stagger := 0.5
@export var limit := 1.0

@export_group("Rock")
## Torso swing speed per 25 damage (rad/s, the spring does the rest), and the head follows.
@export var lean_kick := 5.5

@export_group("Shot leg")
## Downward push on the pelvis when a leg is hit, and how long the pelvis lets go.
@export var buckle := 70.0
@export var buckle_time := 0.5

@export_group("Jolt")
@export var limb_time := 0.45
@export var leg_time := 0.9
@export_range(0.0, 1.0) var grip := 0.03
## Extra spin on the hit bone per 25 damage (rad/s).
@export var spin := 7.0


func _ready() -> void:
	health.damaged.connect(_on_damaged)


func _on_damaged(amount: float, point: Vector3, direction: Vector3, bone: PhysicalBone3D) -> void:
	if not health.alive:
		return

	var weight := clampf(amount / 25.0, 0.4, 2.5)
	var side := signf(direction.x)

	if not movement.input.has_aim:
		movement.facing = -int(side)

	movement.push = clampf(movement.push + side * stagger * weight, -limit, limit)
	spine.jolt(-side * float(movement.facing) * lean_kick * weight)

	var lever := (point - bone.global_position).cross(direction).z
	ragdoll.twist(bone, Vector3.BACK * clampf(lever * 40.0, -1.0, 1.0) * spin * weight)

	var part := String(bone.bone_name).get_slice("_", 1)
	var leg := part.ends_with("Leg") or part.ends_with("Foot")
	for other in ragdoll.physical_bones:
		var other_part := String(other.bone_name).get_slice("_", 1)
		if _linked(other_part, part):
			ragdoll.flinch(other, leg_time if leg else limb_time, grip)

		if not leg:
			continue

		if other_part == "Hips":
			ragdoll.flinch(other, buckle_time, 0.15)
			ragdoll.kick(other, Vector3.DOWN * buckle * weight, Vector3.ZERO)
		elif other_part.ends_with("Leg") or other_part.ends_with("Foot"):
			if not _linked(other_part, part):
				ragdoll.flinch(other, buckle_time, 0.35)


func _linked(other: String, part: String) -> bool:
	if other == part:
		return true

	for side in ["Left", "Right"]:
		if part.begins_with(side) and other.begins_with(side):
			var limb := "Leg" if part.ends_with("Leg") or part.ends_with("Foot") else "Arm"
			return other.ends_with(limb) or other.ends_with("Foot") and limb == "Leg" or other.ends_with("Hand") and limb == "Arm"

	return part == "Head" and other == "Spine1"
