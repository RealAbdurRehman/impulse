class_name StairLink
extends Node3D

const GROUP := &"stair_links"

var goal := 0.0
var steps: StaticBody3D

@onready var _prompt: Node3D = $Prompt


func _ready() -> void:
	add_to_group(GROUP)
	_prompt.hide()


func highlight(on: bool) -> void:
	_prompt.visible = on


func goal_x() -> float:
	return get_parent().to_global(Vector3(goal, 0.0, 0.0)).x


func engage(on: bool) -> void:
	steps.collision_layer = 1 if on else 0
