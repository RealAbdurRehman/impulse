class_name Menu
extends Control

const SANDBOX := "res://scenes/world/sandbox.tscn"
const GAME := {
	&"Quality": &"quality",
	&"Fullscreen": &"fullscreen",
	&"VSync": &"vsync",
	&"Volume": &"volume",
	&"Blood": &"blood",
	&"Dismember": &"dismemberment",
	&"Effects": &"effects",
	&"Indicators": &"indicators",
}

@onready var _pages: Array[Control] = [%Main, %Settings]


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameSettings.current.apply(get_viewport())
	Transition.reveal(get_tree(), 0.0)

	%Quit.visible = not OS.has_feature("web")
	_fill(GAME, GameSettings.current)
	for key in GAME:
		_changed(get_node("%" + key)).connect(_on_game_changed.unbind(1))

	%Play.pressed.connect(_start)
	%SettingsButton.pressed.connect(_open.bind(%Settings))
	%Quit.pressed.connect(get_tree().quit)
	%SettingsBack.pressed.connect(_open.bind(%Main))
	_open(%Main)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not %Main.visible:
		_open(%Main)


func _open(page: Control) -> void:
	for each in _pages:
		each.visible = each == page

	page.find_children("*", "BaseButton", true, false)[0].grab_focus()


func _fill(map: Dictionary, source: Resource) -> void:
	for key in map:
		var widget := get_node("%" + key)
		var value = source.get(map[key])
		if widget is OptionButton:
			widget.selected = value
		elif widget is Range:
			widget.value = value
		else:
			widget.button_pressed = value


func _store(map: Dictionary, target: Resource) -> void:
	for key in map:
		var widget := get_node("%" + key)
		var value = widget.selected if widget is OptionButton else widget.value if widget is Range else widget.button_pressed
		target.set(map[key], type_convert(value, typeof(target.get(map[key]))))


func _changed(widget: Control) -> Signal:
	if widget is OptionButton:
		return widget.item_selected

	return widget.value_changed if widget is Range else widget.toggled


func _on_game_changed() -> void:
	var game := GameSettings.current
	_store(GAME, game)
	game.save()
	game.apply(get_viewport())


func _start() -> void:
	Transition.go(get_tree(), SANDBOX)
