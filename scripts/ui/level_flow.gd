class_name LevelFlow
extends CanvasLayer

enum State {
	PLAYING,
	DEAD,
	WON,
}

@export var prompt_delay := 1.2
@export var win_title := "MISSION COMPLETE"
@export var fail_title := "MISSION FAILED"
@export var win_colour := Color(0.93, 0.93, 0.9)
@export var fail_colour := Color(0.8, 0.16, 0.14)

var state := State.PLAYING

var _zone: ExitZone

@onready var _extraction: Control = %Extraction
@onready var _progress: ProgressBar = %Progress
@onready var _result: Control = %Result
@onready var _title: Label = %Title
@onready var _seed: Label = %Seed


func _ready() -> void:
	_extraction.hide()
	_result.hide()


func start(target: CharacterMovement, zone: ExitZone, level_seed: int) -> void:
	_zone = zone
	_seed.text = "SEED %d" % level_seed
	target.health.died.connect(_on_died)
	zone.completed.connect(_on_completed)


func _process(_delta: float) -> void:
	if _zone == null:
		return

	_extraction.visible = state == State.PLAYING and _zone.held > 0.0
	_progress.value = _zone.held / _zone.hold_time


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if state == State.PLAYING or key == null or not key.pressed or key.echo:
		return

	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		_restart(false)
	elif key.keycode == KEY_N:
		_restart(true)


func _restart(fresh: bool) -> void:
	if fresh:
		Level.new_seed()

	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_died() -> void:
	await get_tree().create_timer(prompt_delay, true, false, true).timeout
	if state == State.PLAYING:
		_show(State.DEAD, fail_title, fail_colour)


func _on_completed() -> void:
	get_tree().paused = true
	_show(State.WON, win_title, win_colour)


func _show(result: State, title: String, colour: Color) -> void:
	state = result
	_title.text = title
	_title.add_theme_color_override("font_color", colour)
	_result.show()
