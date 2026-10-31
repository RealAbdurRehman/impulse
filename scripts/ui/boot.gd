class_name Boot
extends CanvasLayer

const MENU := "res://scenes/ui/menu.tscn"
const SANDBOX := "res://scenes/world/sandbox.tscn"
const PATHS := [MENU, SANDBOX]
const LOAD_SHARE := 0.6
const WARM_TIME := 2.0

static var _kept: Array[Resource] = []

@onready var _progress: ProgressBar = %Progress


func _ready() -> void:
	GameAudio.of(get_tree())
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
			pending = (
				pending
				or ResourceLoader.load_threaded_get_status(path, progress) == ResourceLoader.THREAD_LOAD_IN_PROGRESS
			)
			done += progress[0]

		_progress.value = done / PATHS.size() * LOAD_SHARE
		await get_tree().process_frame

	for path in PATHS:
		_kept.append(ResourceLoader.load_threaded_get(path))


func _warm_up() -> void:
	SoundBank.warm()
	var sandbox := (_kept[1] as PackedScene).instantiate() as Sandbox
	add_child(sandbox)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(sandbox.player.get_node("PlayerInput") as PlayerInput).suspended = true
	for each in sandbox.find_children("*", "", false, false):
		if each is CanvasLayer or each is SpawnMenu or each is SquadCall:
			each.process_mode = Node.PROCESS_MODE_DISABLED

	var tween := create_tween()
	tween.tween_property(_progress, "value", 1.0, WARM_TIME)
	await tween.finished

	sandbox.queue_free()
	await get_tree().process_frame
