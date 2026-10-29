class_name PauseScreen
extends CanvasLayer

const MENU := "res://scenes/ui/menu.tscn"

var _was_paused := false

@onready var _world := get_parent() as Sandbox
@onready var _editor := _world.get_node("SpawnMenu") as SpawnMenu
@onready var _camera := _world.get_node("Camera") as FollowCamera
@onready var _main := $Main as Control
@onready var _controls := %ControlsPage as ControlsPage


func _ready() -> void:
	%Resume.pressed.connect(_close)
	%Restart.pressed.connect(_leave.bind(_world.scene_file_path))
	%MainMenu.pressed.connect(_leave.bind(MENU))
	%ControlsButton.pressed.connect(_show_controls.bind(true))
	_controls.back.connect(_show_controls.bind(false))


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return

	if visible and _controls.visible:
		_show_controls(false)
	elif visible:
		_close()
	elif _world.player.health.alive or _editor.visible:
		_open()
	else:
		return

	get_viewport().set_input_as_handled()


func _open() -> void:
	_show_controls(false)
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


func _show_controls(on: bool) -> void:
	_main.visible = not on
	_controls.visible = on
	if not on:
		(%Resume as Button).grab_focus()
