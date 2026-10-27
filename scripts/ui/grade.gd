class_name Grade
extends CanvasLayer

const SHADER := preload("res://scripts/ui/shaders/grade.gdshader")


func _ready() -> void:
	layer = -1
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = SHADER
	rect.material = material
	add_child(rect)
