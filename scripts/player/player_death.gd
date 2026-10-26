class_name PlayerDeath
extends CharacterDeath

@export var pickup: PlayerPickup
@export var restart_delay := 3.0
@export var auto_restart := true


func _after_death() -> void:
	pickup.set_physics_process(false)
	movement.focus = ragdoll.hips

	if restart_delay > 0.0:
		await get_tree().create_timer(restart_delay, true, false, true).timeout
		if auto_restart:
			get_tree().reload_current_scene()
