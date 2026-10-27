class_name Targeter
extends Node

const INTERVAL := 0.4
const SWITCH_RATIO := 0.6
const FOLLOW_EVERY := 1.0

@export var brain: EnemyInput
@export var player: CharacterMovement

var _left := randf() * INTERVAL
var _follow_left := 0.0


func _physics_process(delta: float) -> void:
	if not brain.health.alive:
		return

	_follow_left -= delta
	_left -= delta
	if _left > 0.0:
		return

	_left = INTERVAL
	var mine := brain.health.team
	var best: CharacterMovement = null
	var best_gap := INF
	for body in _foes(mine):
		var gap := _gap(body)
		if gap < best_gap:
			best = body
			best_gap = gap

	if best == null:
		if mine == player.health.team:
			brain.hostile = false
			brain.retarget(player)
			if _follow_left <= 0.0:
				_follow_left = FOLLOW_EVERY
				brain.follow(player.global_position)

		return

	brain.hostile = true
	var current := brain.target
	var keeping := current.health.alive and current.health.team != mine
	if keeping and best != current and best_gap > _gap(current) * SWITCH_RATIO:
		return

	brain.retarget(best)


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
