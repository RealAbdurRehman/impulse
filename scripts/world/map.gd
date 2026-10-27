@tool
class_name Map
extends Node3D


func _ready() -> void:
	if Engine.is_editor_hint():
		Weathering.fix(self)
