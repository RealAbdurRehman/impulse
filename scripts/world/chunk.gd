class_name Chunk
extends Node3D

enum Role {
	START,
	MIDDLE,
	END,
}

@export var role := Role.MIDDLE

@onready var _entry := $Entry as Marker3D
@onready var _exit := $Exit as Marker3D


func build(_rng: RandomNumberGenerator) -> void:
	pass


func entry_point() -> Vector3:
	return _entry.global_position


func exit_point() -> Vector3:
	return _exit.global_position


func place_after(previous: Chunk) -> void:
	position += previous.exit_point() - ($Entry as Marker3D).position


func spawns() -> Array[ChunkSpawn]:
	var found: Array[ChunkSpawn] = []
	for child in $Enemies.get_children():
		if child is ChunkSpawn:
			found.append(child)

	return found


func objective() -> Marker3D:
	return $Objective
