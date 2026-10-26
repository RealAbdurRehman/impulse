class_name Boot
extends CanvasLayer

const MENU := "res://scenes/ui/menu.tscn"
const LEVEL := "res://scenes/world/level.tscn"
const PATHS := [MENU, LEVEL]
const LOAD_SHARE := 0.6
const WARM_TIME := 2.0

static var _kept: Array[Resource] = []

@onready var _progress: ProgressBar = %Progress


func _ready() -> void:
	for path in PATHS:
		ResourceLoader.load_threaded_request(path, "", true)

	await _load_all()
	await _warm_up()
	Transition.go(get_tree(), MENU)


func _load_all() -> void:
	var progress := []
	var pending := true
	while pending:
		var done := 0.0
		pending = false
		for path in PATHS:
			pending = pending or ResourceLoader.load_threaded_get_status(path, progress) == ResourceLoader.THREAD_LOAD_IN_PROGRESS
			done += progress[0]

		_progress.value = done / PATHS.size() * LOAD_SHARE
		await get_tree().process_frame

	for path in PATHS:
		_kept.append(ResourceLoader.load_threaded_get(path))


func _warm_up() -> void:
	var kept := LevelSettings.current
	var run := LevelSettings.new()
	run.chunk_count = 2
	run.enemies_per_chunk = 1
	run.god_mode = true
	run.peaceful_enemies = true
	LevelSettings.current = run

	var level := (_kept[1] as PackedScene).instantiate()
	add_child(level)
	var tween := create_tween()
	tween.tween_property(_progress, "value", 1.0, WARM_TIME)
	await tween.finished

	level.queue_free()
	await get_tree().process_frame
	LevelSettings.current = kept
