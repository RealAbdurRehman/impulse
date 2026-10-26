class_name PlayerStairs
extends Node

const LANE := -1.1

@export var reach := 0.45
@export var arrive := 0.12
@export var shift_speed := 2.6

var _hover: StairLink
var _climb: StairLink
var _start := 0.0
var _goal := 0.0

@onready var _movement := get_parent() as CharacterMovement
@onready var _gait := _movement.find_children("*", "GaitDriver", true, false)[0] as GaitDriver


func _init() -> void:
	process_physics_priority = -90


func _physics_process(delta: float) -> void:
	var lane := LANE if _climb != null else 0.0
	_shift(move_toward(_movement.plane_z, lane, shift_speed * delta) - _movement.plane_z)

	if _climb != null:
		_walk()
		return

	var feet := _movement.global_position
	var best: StairLink = null
	var best_gap := reach
	for node in get_tree().get_nodes_in_group(StairLink.GROUP):
		var link := node as StairLink
		var gap := absf(link.global_position.x - feet.x)
		if gap < best_gap and absf(link.global_position.y - feet.y) < 1.0:
			best_gap = gap
			best = link

	if best != _hover:
		if is_instance_valid(_hover):
			_hover.highlight(false)

		_hover = best
		if _hover != null:
			_hover.highlight(true)

	if _hover != null and _movement.input.interact_pressed and _movement.health.alive and is_zero_approx(_movement.plane_z):
		_begin(_hover)


func _begin(link: StairLink) -> void:
	_climb = link
	_start = _movement.global_position.x
	_goal = link.goal_x()
	_hover = null
	link.highlight(false)
	link.engage(true)


func _walk() -> void:
	var x := _movement.global_position.x
	var held := Input.get_axis("move_left", "move_right")
	if held != 0.0 and signf(held) != signf(_goal - x):
		var back := _start
		_start = _goal
		_goal = back

	if absf(_goal - x) < arrive or not _movement.health.alive:
		_climb.engage(false)
		_climb = null
		return

	_movement.input.move = signf(_goal - x)


func _shift(dz: float) -> void:
	if is_zero_approx(dz):
		return

	var by := Vector3(0.0, 0.0, dz)
	_movement.plane_z += dz
	_movement.global_position += by
	_gait.shift_feet(by)
	for bone: PhysicalBone3D in _movement.find_children("*", "PhysicalBone3D", true, false):
		var rid := bone.get_rid()
		var placed: Transform3D = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM)
		placed.origin += by
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, placed)
