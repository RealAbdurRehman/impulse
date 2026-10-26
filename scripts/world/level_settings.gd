class_name LevelSettings
extends Resource

enum Difficulty {
	EASY,
	NORMAL,
	HARD,
}

const PATH := "user://run.tres"
const SKILL := {
	Difficulty.EASY: Vector2(0.15, 0.55),
	Difficulty.NORMAL: Vector2(0.3, 0.8),
	Difficulty.HARD: Vector2(0.55, 1.0),
}
const ATTACKERS := { Difficulty.EASY: 2, Difficulty.NORMAL: 3, Difficulty.HARD: 4 }

static var current := _load()

@export_range(2, 20) var chunk_count := 3
@export_range(0, 6) var enemies_per_chunk := 2
@export var difficulty := Difficulty.NORMAL

@export_group("Rules")
@export_range(3, 10) var start_bandages := 4
@export var god_mode := false
@export var infinite_ammo := false
@export var infinite_stamina := false
@export var peaceful_enemies := false


static func _load() -> LevelSettings:
	if ResourceLoader.exists(PATH):
		return ResourceLoader.load(PATH, "", ResourceLoader.CACHE_MODE_IGNORE)

	return LevelSettings.new()


func save() -> void:
	ResourceSaver.save(self, PATH)
