class_name PlayerStamina
extends Node

@export var movement: CharacterMovement
@export var input: ActorInput
@export var health: Health

@export var infinite := false
@export var max_stamina := 100.0
@export var sprint_drain := 12.0
@export var jump_cost := 10.0

@export_group("Recovery")
@export var regen_delay := 1.0
@export var regen_moving := 16.0
@export var regen_resting := 28.0
@export_range(0.0, 1.0) var recover_at := 0.25

@export_group("Winded")
@export_range(0.3, 1.0) var winded_move_scale := 0.85

var current := 0.0
var exhausted := false

var _rest := 0.0


func _init() -> void:
	process_physics_priority = -40


func _ready() -> void:
	current = max_stamina
	movement.jumped.connect(_on_jumped)
	health.died.connect(set_physics_process.bind(false))


func fraction() -> float:
	return current / max_stamina


func _physics_process(delta: float) -> void:
	if exhausted:
		input.sprint = false
		input.move *= winded_move_scale

	if input.jump_pressed and current < jump_cost:
		input.jump_pressed = false

	if _sprinting():
		_spend(sprint_drain * delta)
	elif _rest > 0.0:
		_rest -= delta
	else:
		var resting := movement.grounded and absf(input.move) < 0.1
		current = minf(current + (regen_resting if resting else regen_moving) * delta, max_stamina)

	if exhausted and current >= max_stamina * recover_at:
		exhausted = false


func _sprinting() -> bool:
	return (
		input.sprint and movement.grounded and not movement.crouching
		and not movement.moving_backward and movement.aim_amount < 0.1
		and movement.move_speed > movement.walk_speed + 0.05
	)


func _on_jumped() -> void:
	_spend(jump_cost)


func _spend(amount: float) -> void:
	if infinite:
		return

	current = maxf(current - amount, 0.0)
	_rest = regen_delay
	if current <= 0.0:
		exhausted = true
