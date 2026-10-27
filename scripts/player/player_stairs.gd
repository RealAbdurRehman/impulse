class_name PlayerStairs
extends StairClimber

@export var reach := 0.45

var _hover: StairLink


func _idle() -> void:
	var feet := _movement.global_position
	var best: StairLink = null
	var best_gap := reach
	for node in get_tree().get_nodes_in_group(StairLink.GROUP):
		var candidate := node as StairLink
		var gap := absf(candidate.global_position.x - feet.x)
		if gap < best_gap and absf(candidate.global_position.y - feet.y) < 1.0:
			best_gap = gap
			best = candidate

	if best != _hover:
		if is_instance_valid(_hover):
			_hover.highlight(false)

		_hover = best
		if _hover != null:
			_hover.highlight(true)

	if _hover != null and _movement.input.interact_pressed and begin(_hover):
		_hover.highlight(false)
		_hover = null


func _reversed() -> bool:
	var held := Input.get_axis("move_left", "move_right")
	return held != 0.0 and signf(held) != signf(_goal - _movement.global_position.x)
