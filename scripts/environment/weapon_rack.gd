class_name WeaponRack
extends Node3D

@export var weapons: Array[WeaponStats] = []
@export var columns := 3
@export var cell := Vector2(1.0, 0.4)


func _ready() -> void:
	var rows := ceili(float(weapons.size()) / float(columns))
	for i in weapons.size():
		var col := i % columns
		var row := floori(float(i) / float(columns))

		var pickup := WeaponPickup.new()
		pickup.stats = weapons[i]
		pickup.hanging = true
		pickup.position = Vector3(
			(float(col) - float(columns - 1) * 0.5) * cell.x,
			(float(rows - 1) * 0.5 - float(row)) * cell.y,
			0.0,
		)
		add_child(pickup)
		pickup.position -= pickup.local_center() * Vector3(1.0, 1.0, 0.0)
