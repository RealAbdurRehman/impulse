class_name Transition
extends CanvasLayer

const FADE := 0.25
const SETTLE := 0.5

static var _shared: Transition

var _cover := ColorRect.new()


static func go(tree: SceneTree, path: String) -> void:
	await _of(tree)._fade(1.0)
	tree.paused = false
	tree.change_scene_to_file(path)


static func reveal(tree: SceneTree, settle := SETTLE) -> void:
	await tree.create_timer(settle, true, false, true).timeout
	_of(tree)._fade(0.0)


static func _of(tree: SceneTree) -> Transition:
	if _shared == null:
		_shared = Transition.new()
		tree.root.add_child(_shared)

	return _shared


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cover.color = Color.BLACK
	_cover.modulate.a = 0.0
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_cover)


func _fade(to: float) -> void:
	var tween := create_tween().set_ignore_time_scale()
	tween.tween_property(_cover, "modulate:a", to, FADE)
	await tween.finished
