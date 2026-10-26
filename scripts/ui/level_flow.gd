class_name LevelFlow
extends CanvasLayer

enum State {
	PLAYING,
	PAUSED,
	DEAD,
	WON,
}

const MENU := "res://scenes/ui/menu.tscn"

@export var prompt_delay := 1.2

var state := State.PLAYING

var _zone: ExitZone
var _target: CharacterMovement

@onready var _extraction: Control = %Extraction
@onready var _progress: ProgressBar = %Progress
@onready var _screens: Control = %Screens
@onready var _seed: Label = %SeedValue
@onready var _pages := {
	State.PAUSED: %Pause,
	State.DEAD: %Failed,
	State.WON: %Won,
}


func _ready() -> void:
	_extraction.hide()
	_screens.hide()


func start(target: CharacterMovement, zone: ExitZone, level_seed: int) -> void:
	_target = target
	_zone = zone
	_seed.text = str(level_seed)
	target.health.died.connect(_on_died)
	zone.completed.connect(_show.bind(State.WON, true))


func _process(_delta: float) -> void:
	_extraction.visible = state == State.PLAYING and _zone.held > 0.0
	_progress.value = _zone.held / _zone.hold_time


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return

	if state == State.PLAYING:
		if key.keycode == KEY_ESCAPE and _target.health.alive:
			_show(State.PAUSED, true)

		return

	match key.keycode:
		KEY_ESCAPE:
			if state == State.PAUSED:
				get_tree().paused = false
				state = State.PLAYING
				_screens.hide()
			else:
				Transition.go(get_tree(), MENU)
		KEY_M:
			Transition.go(get_tree(), MENU)
		KEY_ENTER, KEY_KP_ENTER:
			Transition.go(get_tree(), get_tree().current_scene.scene_file_path)
		KEY_N:
			Level.new_seed()
			Transition.go(get_tree(), get_tree().current_scene.scene_file_path)


func _on_died() -> void:
	await get_tree().create_timer(prompt_delay, true, false, true).timeout
	if state == State.PLAYING:
		_show(State.DEAD, false)


func _show(next: State, pause: bool) -> void:
	state = next
	get_tree().paused = pause
	_screens.show()
	for page in _pages:
		_pages[page].visible = page == next
