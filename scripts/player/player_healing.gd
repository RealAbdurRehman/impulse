class_name PlayerHealing
extends Node

@export var health: Health
@export var movement: CharacterMovement
@export var input: ActorInput

@export var bandages := 3

@export_group("Bandage")
@export var apply_time := 2.6
@export var heal_amount := 30.0
@export var heal_time := 6.0
@export_range(0.1, 1.0) var move_scale := 0.5
@export var look_limits := Vector2(-70.0, 35.0)

@export_group("Bleeding")
@export var bleed_per_damage := 0.035
@export var clot_time := 35.0
@export var min_damage := 3.0
@export var merge_reach := 0.09
@export var max_wounds := 6

class Wound:
	var bone: PhysicalBone3D
	var local := Vector3.ZERO
	var rate := 0.0
	var left := 0.0
	var tick := 0
	var order := 0

var progress := 0.0

var _wounds: Array[Wound] = []
var _target: Wound
var _band: Bleeding.Band
var _regen := 0.0
var _orders := 0


func _init() -> void:
	process_physics_priority = -50


func _ready() -> void:
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


func is_applying() -> bool:
	return _target != null


func bleed_rate() -> float:
	var total := 0.0
	for wound in _wounds:
		total += _loss(wound)

	return total


func open_wounds() -> int:
	return _wounds.size()


func _physics_process(delta: float) -> void:
	_bleed(delta)

	if _regen > 0.0:
		var step := minf(_regen, heal_amount / heal_time * delta)
		_regen -= step
		health.heal(step)

	if _target != null:
		_apply(delta)
	elif input.heal_pressed and bandages > 0 and not _wounds.is_empty() and _free_to_start():
		_start()


func _on_damaged(amount: float, point: Vector3, _direction: Vector3, bone: PhysicalBone3D) -> void:
	if _target != null:
		_cancel()

	if amount >= min_damage:
		_open(amount, point, bone)


func _on_died() -> void:
	if _target != null:
		_cancel()

	set_physics_process(false)


func _open(amount: float, point: Vector3, bone: PhysicalBone3D) -> void:
	var local := bone.global_transform.affine_inverse() * point
	var rate := amount * bleed_per_damage

	for wound in _wounds:
		if wound.bone == bone and wound.local.distance_to(local) < merge_reach:
			wound.rate += rate
			wound.left = clot_time
			_stamp(wound)
			return

	var wound := Wound.new()
	wound.bone = bone
	wound.local = local
	wound.rate = rate
	wound.left = clot_time
	_stamp(wound)
	_wounds.append(wound)

	if _wounds.size() > max_wounds:
		_wounds.remove_at(0)


func _stamp(wound: Wound) -> void:
	_orders += 1
	wound.tick = Engine.get_physics_frames()
	wound.order = _orders


func _bleed(delta: float) -> void:
	var loss := 0.0
	for wound in _wounds:
		loss += _loss(wound)
		wound.left = maxf(wound.left - delta, 0.0)

	if loss > 0.0:
		health.drain(loss * delta)


func _loss(wound: Wound) -> float:
	return wound.rate * clampf(wound.left / clot_time, 0.0, 1.0)


func _free_to_start() -> bool:
	return movement.grounded and not (input.fire or input.sprint or input.aim or input.jump)


func _start() -> void:
	var pick: Wound = _wounds[0]
	for wound in _wounds:
		if wound.tick > pick.tick or (wound.tick == pick.tick and wound.order < pick.order):
			pick = wound

	_target = pick
	progress = 0.0
	var soak := clampf(_loss(pick) / (bleed_per_damage * 25.0), 0.2, 1.0)
	_band = health.bleeding.bandage(pick.bone, pick.local, apply_time, soak)


func _apply(delta: float) -> void:
	var broken := not movement.grounded or input.fire or input.sprint or input.aim or input.jump_pressed
	broken = broken or input.reload_pressed or input.interact_pressed or input.heal_pressed
	if broken:
		_cancel()
		return

	progress += delta / apply_time
	input.move *= move_scale
	_look()

	if progress >= 1.0:
		_finish()


func _look() -> void:
	var shoulder := movement.global_position + Vector3.UP * movement.aim_origin_height
	var to := input.aim_point - shoulder
	var side := float(movement.facing)
	if absf(input.aim_point.x - movement.global_position.x) > movement.aim_deadzone:
		side = signf(to.x)

	var pitch := clampf(atan2(to.y, maxf(absf(to.x), 0.001)), deg_to_rad(look_limits.x), deg_to_rad(look_limits.y))
	input.aim_point = shoulder + Vector3(side * cos(pitch), sin(pitch), 0.0) * maxf(to.length(), 1.0)


func _finish() -> void:
	health.bleeding.staunch(_target.bone)
	_wounds.erase(_target)
	_target = null
	_band = null
	progress = 0.0
	_regen += heal_amount
	bandages -= 1


func _cancel() -> void:
	health.bleeding.unbandage(_band)
	_target = null
	_band = null
	progress = 0.0
