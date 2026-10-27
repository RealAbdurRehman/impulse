class_name PlayerLoot
extends Node

signal collected(type: StringName, amount: int)

@export var reach := 0.9

@onready var _movement := get_parent() as CharacterMovement
@onready var _carrier := get_parent().get_node("WeaponCarrier") as WeaponCarrier


func _ready() -> void:
	_movement.health.died.connect(queue_free)


func _physics_process(_delta: float) -> void:
	var pouch := _carrier.weapon.pouch
	if pouch == null:
		return

	var feet := _movement.global_position
	for node in get_tree().get_nodes_in_group(AmmoPickup.GROUP):
		var pickup := node as AmmoPickup
		var gap := pickup.global_position - feet
		if absf(gap.x) > reach or gap.y < -0.4 or gap.y > 1.6:
			continue

		var taken := pouch.add(pickup.type, pickup.count)
		if taken > 0:
			pickup.count -= taken
			collected.emit(pickup.type, taken)
			if pickup.count <= 0:
				pickup.queue_free()
