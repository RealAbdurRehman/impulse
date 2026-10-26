class_name ValueLabel
extends Label

@export var source: Range
@export var factor := 100.0


func _ready() -> void:
	source.value_changed.connect(_show)
	_show(source.value)


func _show(value: float) -> void:
	text = str(roundi(value * factor))
