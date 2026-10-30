@tool
class_name ScenarioLoot
extends ScenarioMarker

@export_enum("pistol", "rifle", "shotgun", "sniper") var ammo := "rifle":
	set(value):
		ammo = value
		_refresh()
@export var gun := false:
	set(value):
		gun = value
		_refresh()
@export var count := 30:
	set(value):
		count = value
		_refresh()


func release(menu: SpawnMenu) -> void:
	if gun:
		var picked := menu.weapons.filter(func(each: WeaponStats) -> bool: return each.ammo_type == ammo)
		var stats := picked[0] as WeaponStats
		WeaponPickup.spawn(
			menu.world,
			stats,
			stats.magazine_size,
			Transform3D(Basis.IDENTITY, global_position),
			Vector3.ZERO,
			0.0,
		)
	else:
		AmmoPickup.spawn(menu.world, ammo, count, global_position, Vector3.ZERO)


func _caption() -> String:
	return "%s GUN" % ammo.to_upper() if gun else "%s x%d" % [ammo.to_upper(), count]


func _color() -> Color:
	return Color(1.0, 0.8, 0.3, 0.6) if gun else Color(0.4, 0.75, 1.0, 0.6)


func _mesh() -> Mesh:
	var box := BoxMesh.new()
	box.size = Vector3(0.6, _height(), 0.3) if gun else Vector3(0.3, _height(), 0.3)
	return box


func _height() -> float:
	return 0.3
