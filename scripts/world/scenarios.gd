class_name Scenarios
extends RefCounted

const SANDBOX := "res://scenes/world/sandbox.tscn"
const SAVE := "user://scenarios.cfg"

static var pending := &""

const LIST := [
	{ "id": &"yard", "title": "Yard", "scene": "res://scenes/scenarios/yard.tscn" },
	{ "id": &"stairs", "title": "Stairs", "scene": "res://scenes/scenarios/stairs.tscn" },
	{ "id": &"checkpoint", "title": "Checkpoint", "scene": "res://scenes/scenarios/checkpoint.tscn" },
]


static func find(id: StringName) -> Dictionary:
	for each: Dictionary in LIST:
		if each.id == id:
			return each

	return { }


static func id_of(scene: String) -> StringName:
	for each: Dictionary in LIST:
		if each.scene == scene:
			return each.id

	return &""


static func play(tree: SceneTree, id: StringName) -> void:
	pending = id
	Transition.go(tree, SANDBOX)


static func best(id: StringName) -> float:
	var file := ConfigFile.new()
	file.load(SAVE)
	return file.get_value("best", String(id), 0.0)


static func record(id: StringName, seconds: float) -> bool:
	var file := ConfigFile.new()
	file.load(SAVE)
	var old: float = file.get_value("best", String(id), 0.0)
	var improved := old <= 0.0 or seconds < old
	if improved:
		file.set_value("best", String(id), seconds)
		file.save(SAVE)

	return improved


static func clock(seconds: float) -> String:
	return "%d:%02d" % [floori(seconds / 60.0), int(seconds) % 60]
