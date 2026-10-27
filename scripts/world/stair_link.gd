class_name StairLink
extends Node3D

const GROUP := &"stair_links"

@export var goal := 0.0
@export var lift := 0.0
@export var steps: StaticBody3D

@onready var _prompt: Node3D = $Prompt


func _ready() -> void:
	add_to_group(GROUP)
	_prompt.hide()


func highlight(on: bool) -> void:
	_prompt.visible = on


func goal_x() -> float:
	return get_parent().to_global(Vector3(goal, 0.0, 0.0)).x


func goal_y() -> float:
	return global_position.y + lift


func hold(on: bool) -> void:
	var holds := maxi(int(steps.get_meta(&"holds", 0)) + (1 if on else -1), 0)
	steps.set_meta(&"holds", holds)
	steps.collision_layer = 1 if holds > 0 else 0
