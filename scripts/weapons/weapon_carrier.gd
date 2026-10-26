class_name WeaponCarrier
extends Node

@export var weapon: Weapon

@export_group("Throw")
@export var throw_velocity := Vector2(1.0, 1.2)
@export var throw_spin := 4.0

@export var drop_velocity := Vector2(0.2, 0.0)


func drop() -> void:
	_throw(weapon, weapon.holder, drop_velocity)
	_retire(weapon.holder, weapon)


func swap(stats: WeaponStats, ammo: int) -> void:
	var old_weapon := weapon
	var old_holder := weapon.holder
	_throw(old_weapon, old_holder, throw_velocity)

	var holder := GunHolder.new()
	holder.spine = old_holder.spine
	holder.ragdoll = old_holder.ragdoll

	weapon = Weapon.new()
	weapon.stats = stats
	weapon.holder = holder
	weapon.character = old_weapon.character
	weapon.volume_db = old_weapon.volume_db
	weapon.infinite_ammo = old_weapon.infinite_ammo
	holder.weapon = weapon

	var parent := old_weapon.get_parent()
	parent.add_child(holder)
	parent.add_child(weapon)

	if ammo >= 0:
		weapon.ammo = ammo

	holder.assembled.connect(_retire.bind(old_holder, old_weapon), CONNECT_ONE_SHOT)


func _throw(old_weapon: Weapon, old_holder: GunHolder, toss: Vector2) -> void:
	var character := old_weapon.character
	var facing := float(character.facing)
	var held := old_holder.gun.global_transform
	var angle := atan2(held.basis.x.y, absf(held.basis.x.x))
	var at := Transform3D(
		Basis(Vector3.UP, PI if facing < 0.0 else 0.0) * Basis(Vector3.BACK, angle),
		Vector3(held.origin.x, held.origin.y, character.plane_z),
	)

	old_weapon.set_physics_process(false)

	character.aim_amount = 0.0
	character.aim_speed_scale = 1.0
	character.aim_zoom = 1.0
	character.aim_look = 1.0

	var spin := -facing * throw_spin
	if absf(angle) > 0.15:
		spin *= signf(angle)

	var velocity := Vector3(character.velocity.x + facing * toss.x, toss.y, 0.0)
	WeaponPickup.spawn(
		character.get_parent(),
		old_weapon.stats,
		old_weapon.ammo,
		at,
		velocity,
		spin,
	)


func _retire(old_holder: GunHolder, old_weapon: Weapon) -> void:
	old_holder.release()
	old_holder.queue_free()
	old_weapon.queue_free()
