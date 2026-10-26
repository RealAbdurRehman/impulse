class_name Menu
extends Control

const LEVEL := "res://scenes/world/level.tscn"
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
const RUN := {
	&"Chunks": &"chunk_count",
	&"Enemies": &"enemies_per_chunk",
	&"Difficulty": &"difficulty",
	&"Bandages": &"start_bandages",
	&"God": &"god_mode",
	&"InfiniteAmmo": &"infinite_ammo",
	&"InfiniteStamina": &"infinite_stamina",
	&"Peaceful": &"peaceful_enemies",
}

@onready var _pages: Array[Control] = [%Main, %NewGame, %Settings]
@onready var _seed: LineEdit = %SeedField


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameSettings.current.apply(get_viewport())
	Transition.reveal(get_tree(), 0.0)

	%Quit.visible = not OS.has_feature("web")
	_fill(GAME, GameSettings.current)
	_fill(RUN, LevelSettings.current)
	for key in GAME:
		_changed(get_node("%" + key)).connect(_on_game_changed.unbind(1))

	%NewGameButton.pressed.connect(_open.bind(%NewGame))
	%SettingsButton.pressed.connect(_open.bind(%Settings))
	%Quit.pressed.connect(get_tree().quit)
	%NewBack.pressed.connect(_open.bind(%Main))
	%SettingsBack.pressed.connect(_open.bind(%Main))
	%Start.pressed.connect(_start)
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
	_store(RUN, LevelSettings.current)
	LevelSettings.current.save()

	var word := _seed.text.strip_edges()
	if word.is_empty():
		Level.new_seed()
	else:
		Level.run_seed = maxi(1, word.hash() & 0x7fffffff)

	Transition.go(get_tree(), LEVEL)
