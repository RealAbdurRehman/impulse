class_name PlayerPickup
extends Node
## Highlights the weapon within reach and swaps to it when interact is pressed.

@export var carrier: WeaponCarrier

@export_group("Pickup")
@export var reach := 1.5
@export var reach_height := 1.0

var _hover: WeaponPickup


func _physics_process(_delta: float) -> void:
	_update_hover()

	var weapon := carrier.weapon
	if not weapon.holder.gun.is_inside_tree():
		return

	if weapon.character.input.interact_pressed and _hover != null:
		var pickup := _hover
		_hover = null
		carrier.swap(pickup.stats, pickup.ammo)
		pickup.queue_free()


func _update_hover() -> void:
	var character := carrier.weapon.character
	var from := character.global_position + Vector3.UP * reach_height

	var best: WeaponPickup = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(WeaponPickup.GROUP):
		var pickup := node as WeaponPickup
		var centre := pickup.center()
		centre.z = from.z
		if centre.distance_to(from) > reach:
			continue

		var distance := centre.distance_to(character.aim_point)
		if distance < best_distance:
			best_distance = distance
			best = pickup

	if best == _hover:
		return

	if _hover != null:
		_hover.highlight(false)

	_hover = best
	if _hover != null:
		_hover.highlight(true)
