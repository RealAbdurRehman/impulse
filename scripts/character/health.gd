class_name Health
extends Node

signal damaged(amount: float, point: Vector3, direction: Vector3, bone: PhysicalBone3D)
signal died
signal corpse_struck(amount: float, point: Vector3, direction: Vector3, bone: PhysicalBone3D)

@export var ragdoll: PhysicalBoneSimulator3D
@export var max_health := 100.0

@export var team: StringName = &""

@export_group("Hit zones")
@export var head_multiplier := 3.0
@export var limb_multiplier := 0.75

@export var corpse_impulse_scale := 1.0

@export var blow_window := 0.1

var current := 0.0
var alive := true
var immortal := false
var bleeding: Bleeding
var dismemberment: Dismemberment

var last_bone: PhysicalBone3D
var last_direction := Vector3.ZERO
var last_amount := 0.0

var blow := 0.0
var _blow_tick := -1000


static func of(collider: Object) -> Health:
	if collider.has_meta(&"health"):
		return collider.get_meta(&"health") as Health

	return null


func _ready() -> void:
	current = max_health
	dismemberment = Dismemberment.new()
	dismemberment.name = &"Dismemberment"
	add_child(dismemberment)

	bleeding = Bleeding.new()
	bleeding.name = &"Bleeding"
	add_child(bleeding)

	for bone in ragdoll.get_children():
		if bone is PhysicalBone3D:
			bone.set_meta(&"health", self)
			for child in bone.get_children():
				if child is Area3D:
					child.set_meta(&"health", self)


func hit(
	amount: float,
	point: Vector3,
	direction: Vector3,
	bone: PhysicalBone3D,
	impulse := 0.0,
) -> void:
	if not alive:
		corpse_struck.emit(amount * _zone(bone), point, direction, bone)
		return

	var tick := Engine.get_physics_frames()
	if float(tick - _blow_tick) > blow_window * Engine.physics_ticks_per_second:
		blow = 0.0

	blow += impulse
	_blow_tick = tick

	amount *= _zone(bone)
	current = maxf(current - amount, _floor())
	last_bone = bone
	last_direction = direction
	last_amount = amount
	damaged.emit(amount, point, direction, bone)

	if current <= 0.0:
		alive = false
		died.emit()


func heal(amount: float) -> void:
	current = minf(current + amount, max_health)


func drain(amount: float) -> void:
	if not alive:
		return

	current = maxf(current - amount, _floor())
	if current <= 0.0:
		alive = false
		died.emit()


func _floor() -> float:
	return 1.0 if immortal else 0.0


func impulse_scale() -> float:
	return 1.0 if alive else corpse_impulse_scale


func _zone(bone: PhysicalBone3D) -> float:
	var part := String(bone.bone_name)
	if part.ends_with("Head"):
		return head_multiplier

	for limb in ["Arm", "Hand", "Leg", "Foot"]:
		if limb in part:
			return limb_multiplier

	return 1.0
