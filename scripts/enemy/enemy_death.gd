class_name EnemyDeath
extends CharacterDeath


func _on_died() -> void:
	AmmoLoot.drop(movement.get_parent(), movement.global_position + Vector3.UP, carrier.weapon.stats)
	super()
