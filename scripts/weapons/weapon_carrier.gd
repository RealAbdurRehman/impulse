class_name WeaponCarrier
extends Node

@export var weapon: Weapon

@export_group("Input")
@export var interact_action: StringName = &"interact"

@export_group("Pickup")
@export var reach := 1.5
@export var reach_height := 1.0

@export_group("Throw")
@export var throw_velocity := Vector2(1.0, 1.2)
@export var throw_spin := 4.0

var _hover: WeaponPickup


func _physics_process(_delta: float) -> void:
	_update_hover()

	if not weapon.holder.gun.is_inside_tree():
		return

	if Input.is_action_just_pressed(interact_action) and _hover != null:
		var pickup := _hover
		_hover = null
		_swap(pickup.stats, pickup.ammo)
		pickup.queue_free()


func _swap(stats: WeaponStats, ammo: int) -> void:
	var old_weapon := weapon
	var old_holder := weapon.holder
	_throw(old_weapon, old_holder)

	var holder := GunHolder.new()
	holder.spine = old_holder.spine
	holder.ragdoll = old_holder.ragdoll

	weapon = Weapon.new()
	weapon.stats = stats
	weapon.holder = holder
	weapon.player = old_weapon.player
	holder.weapon = weapon

	var parent := old_weapon.get_parent()
	parent.add_child(holder)
	parent.add_child(weapon)

	if ammo >= 0:
		weapon.ammo = ammo

	holder.assembled.connect(_retire.bind(old_holder, old_weapon), CONNECT_ONE_SHOT)


func _throw(old_weapon: Weapon, old_holder: GunHolder) -> void:
	var player := old_weapon.player
	var facing := float(player.facing)
	var held := old_holder.gun.global_transform
	var angle := atan2(held.basis.x.y, absf(held.basis.x.x))
	var at := Transform3D(
		Basis(Vector3.UP, PI if facing < 0.0 else 0.0) * Basis(Vector3.BACK, angle),
		Vector3(held.origin.x, held.origin.y, player.plane_z),
	)

	old_weapon.set_physics_process(false)

	player.aim_amount = 0.0
	player.aim_speed_scale = 1.0
	player.aim_zoom = 1.0

	var spin := -facing * throw_spin
	if absf(angle) > 0.15:
		spin *= signf(angle)

	var velocity := Vector3(player.velocity.x + facing * throw_velocity.x, throw_velocity.y, 0.0)
	WeaponPickup.spawn(player.get_parent(), old_weapon.stats, old_weapon.ammo, at, velocity, spin)


func _retire(old_holder: GunHolder, old_weapon: Weapon) -> void:
	old_holder.release()
	old_holder.queue_free()
	old_weapon.queue_free()


func _update_hover() -> void:
	var player := weapon.player
	var from := player.global_position + Vector3.UP * reach_height

	var best: WeaponPickup = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(WeaponPickup.GROUP):
		var pickup := node as WeaponPickup
		var centre := pickup.center()
		centre.z = from.z
		if centre.distance_to(from) > reach:
			continue

		var distance := centre.distance_to(player.aim_point)
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
