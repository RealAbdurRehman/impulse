class_name LevelSettings
extends Resource

enum Difficulty {
	EASY,
	NORMAL,
	HARD,
}

const SKILL := {
	Difficulty.EASY: Vector2(0.15, 0.55),
	Difficulty.NORMAL: Vector2(0.3, 0.8),
	Difficulty.HARD: Vector2(0.55, 1.0),
}

const ATTACKERS := { Difficulty.EASY: 2, Difficulty.NORMAL: 3, Difficulty.HARD: 4 }

@export_range(2, 20) var chunk_count := 3
@export_range(0, 6) var enemies_per_chunk := 2

@export var difficulty := Difficulty.NORMAL
@export var level_seed := 0
