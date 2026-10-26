class_name ChunkSpawn
extends EnemySpawn

enum Role {
	ANY,
	SNIPER,
}

@export var role := Role.ANY


func _init() -> void:
	spawn_on_ready = false


func arm(who: CharacterMovement, scene: PackedScene) -> void:
	target = who
	if enemy_scene == null:
		enemy_scene = scene

	set_physics_process(true)
