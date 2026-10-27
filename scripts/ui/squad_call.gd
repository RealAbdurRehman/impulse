class_name SquadCall
extends CanvasLayer

const DESIGN_HEIGHT := 1080.0
const MARGIN := 28.0
const LIFT := 150.0

@export var follow_text := "ALLIES: FOLLOW"
@export var hold_text := "ALLIES: HOLD"

@onready var _mode: Label = %Mode


func _ready() -> void:
	Targeter.call_squad(false)
	_show()


func _process(_delta: float) -> void:
	var height := get_viewport().get_visible_rect().size.y
	var k := height / DESIGN_HEIGHT
	_mode.scale = Vector2.ONE * k
	_mode.position = Vector2(MARGIN * k, height - LIFT * k)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_V:
		Targeter.call_squad(not Targeter.following)
		_show()


func _show() -> void:
	_mode.text = follow_text if Targeter.following else hold_text
