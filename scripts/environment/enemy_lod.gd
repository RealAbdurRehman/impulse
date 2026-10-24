class_name EnemyLod
extends Node

@export var target: CharacterMovement
@export var freeze_distance := 45.0
@export var wake_distance := 38.0
@export var interval := 0.25

var _left := 0.0


func _physics_process(delta: float) -> void:
	_left -= delta
	if _left > 0.0:
		return

	_left = interval
	var origin := target.global_position
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var brain := node as EnemyInput
		var body := brain.get_parent() as CharacterMovement
		var calm := brain.is_calm()
		var distance := body.global_position.distance_to(origin)
		if body.process_mode == Node.PROCESS_MODE_DISABLED:
			if distance < wake_distance or not calm:
				body.process_mode = Node.PROCESS_MODE_INHERIT
		elif distance > freeze_distance and calm:
			body.process_mode = Node.PROCESS_MODE_DISABLED
