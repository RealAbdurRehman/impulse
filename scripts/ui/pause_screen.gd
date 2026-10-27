class_name PauseScreen
extends CanvasLayer

const MENU := "res://scenes/ui/menu.tscn"

var _was_paused := false

@onready var _world := get_parent() as Sandbox
@onready var _editor := _world.get_node("SpawnMenu") as SpawnMenu
@onready var _camera := _world.get_node("Camera") as FollowCamera


func _ready() -> void:
	%Resume.pressed.connect(_close)
	%Restart.pressed.connect(_leave.bind(_world.scene_file_path))
	%MainMenu.pressed.connect(_leave.bind(MENU))


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return

	if visible:
		_close()
	elif _world.player.health.alive or _editor.visible:
		_open()
	else:
		return

	get_viewport().set_input_as_handled()


func _open() -> void:
	_was_paused = get_tree().paused
	visible = true
	get_tree().paused = true
	_editor.process_mode = Node.PROCESS_MODE_DISABLED
	_camera.set_reticle(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(%Resume as Button).grab_focus()


func _close() -> void:
	visible = false
	get_viewport().gui_release_focus()
	_editor.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = _was_paused
	if not _editor.visible:
		_camera.set_reticle(true)
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _leave(path: String) -> void:
	for button in find_children("*", "Button", true, false):
		(button as Button).disabled = true

	Transition.go(get_tree(), path)
