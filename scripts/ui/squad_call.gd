class_name SquadCall
extends CanvasLayer


func _ready() -> void:
	Targeter.call_squad(false)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_V:
		Targeter.call_squad(not Targeter.following)
