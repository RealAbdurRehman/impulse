class_name AmmoLoot
extends RefCounted

const GUNS := {
	&"pistol": preload("res://scenes/weapons/g17_stats.tres"),
	&"rifle": preload("res://scenes/weapons/m4a1_stats.tres"),
	&"sniper": preload("res://scenes/weapons/l96a1_stats.tres"),
	&"shotgun": preload("res://scenes/weapons/rem870_stats.tres"),
}
const DROP_CHANCE := 0.85
const SIZE := Vector2(0.4, 1.1)


static func drop(parent: Node, at: Vector3, stats: WeaponStats) -> void:
	if randf() > DROP_CHANCE:
		return

	var rounds := maxi(ceili(float(stats.magazine_size) * lerpf(SIZE.x, SIZE.y, randf())), 1)
	var toss := Vector3(randf_range(-0.8, 0.8), randf_range(1.0, 2.0), 0.0)
	AmmoPickup.spawn(parent, stats.ammo_type, rounds, at, toss)
