class_name Targeter
extends Node

const INTERVAL := 0.4
const SWITCH_RATIO := 0.6
const ENGAGE_RANGE := 16.0
const SQUAD_SIZE := 4

static var following := false
static var squad: Array[EnemyInput] = []


static func call_squad(on: bool) -> void:
	following = on
	squad.clear()

@export var brain: EnemyInput
@export var player: CharacterMovement

var _left := randf() * INTERVAL


func _physics_process(delta: float) -> void:
	if not brain.health.alive:
		return

	_left -= delta
	if _left > 0.0:
		return

	_left = INTERVAL
	var mine := brain.health.team
	var ally := mine == player.health.team
	var member := ally and following and _in_squad()
	var best: CharacterMovement = null
	var best_gap := INF
	for body in _foes(mine):
		if member and body.global_position.distance_to(player.global_position) > ENGAGE_RANGE:
			continue

		var gap := _gap(body)
		if gap < best_gap:
			best = body
			best_gap = gap

	if best == null:
		if ally:
			brain.hostile = false
			brain.retarget(player)
			brain.leader = player if member else null

		return

	brain.hostile = true
	brain.leader = null
	var current := brain.target
	var keeping := current.health.alive and current.health.team != mine
	if keeping and best != current and best_gap > _gap(current) * SWITCH_RATIO:
		return

	brain.retarget(best)


func _in_squad() -> bool:
	squad = squad.filter(func(b: EnemyInput) -> bool: return is_instance_valid(b) and b.health.alive)
	if squad.has(brain):
		return true

	var room := SQUAD_SIZE - squad.size()
	if room <= 0:
		return false

	var waiting: Array[EnemyInput] = []
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var other := node as EnemyInput
		if other.health.alive and other.health.team == brain.health.team and not squad.has(other):
			waiting.append(other)

	waiting.sort_custom(func(a: EnemyInput, b: EnemyInput) -> bool: return _from_player(a) < _from_player(b))
	if waiting.find(brain) < room:
		squad.append(brain)
		return true

	return false


func _from_player(other: EnemyInput) -> float:
	return other.get_parent().global_position.distance_to(player.global_position)


func _foes(mine: StringName) -> Array[CharacterMovement]:
	var found: Array[CharacterMovement] = []
	if player.health.alive and player.health.team != mine:
		found.append(player)

	for node in get_tree().get_nodes_in_group(&"enemies"):
		var other := node as EnemyInput
		if other.health.alive and other.health.team != mine:
			found.append(other.get_parent() as CharacterMovement)

	return found


func _gap(body: CharacterMovement) -> float:
	return body.global_position.distance_to(brain.get_parent().global_position)
