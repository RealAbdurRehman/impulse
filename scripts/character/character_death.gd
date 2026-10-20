class_name CharacterDeath
extends Node

@export var health: Health
@export var movement: CharacterMovement
@export var gait: GaitDriver
@export var ragdoll: ActiveRagdoll
@export var animated: Node
@export var input: ActorInput
@export var carrier: WeaponCarrier

@export_group("Collapse")
## Seconds for the legs and for the upper body to give out.
@export var head_shot := Vector2(0.12, 0.25)
@export var leg_shot := Vector2(0.15, 0.9)
@export var body_shot := Vector2(0.55, 0.9)

@export_group("Killing blow")
## The bullet that kills still hits: it throws the body (m/s) by how hard it hit
## (Health.blow, N s). Even a light blow throws it throw_min; a heavier one gets
## closer to throw_top, covering 63% of the way at throw_blow. Some of it goes up.
@export var throw_min := 1.0
@export var throw_top := 4.5
@export var throw_blow := 40.0
@export var throw_lift := 0.35
## Backward spin of the torso, per m/s of throw (rad/s).
@export var throw_spin := 1.2


func _ready() -> void:
	health.died.connect(_on_died)


func _on_died() -> void:
	carrier.drop()

	movement.blocker.collision_layer = 0
	input.set_physics_process(false)
	movement.set_physics_process(false)
	gait.set_physics_process(false)
	animated.process_mode = Node.PROCESS_MODE_DISABLED

	var times := _times(String(health.last_bone.bone_name))
	var side := signf(health.last_direction.x)
	var speed := lerpf(throw_min, throw_top, 1.0 - exp(-health.blow / throw_blow))
	ragdoll.collapse(times.x, times.y, Vector3(side, throw_lift, 0.0) * speed, -side * speed * throw_spin)

	_after_death()


func _after_death() -> void:
	pass


func _times(bone: String) -> Vector2:
	if bone.ends_with("Head") or bone.ends_with("Neck"):
		return head_shot

	if "Leg" in bone or "Foot" in bone:
		return leg_shot

	return body_shot
