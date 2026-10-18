class_name EnemySpawn
extends Marker3D
## A place an enemy appears. Set what it is (archetype, gun) and who it hunts,
## turn the marker to face the way the enemy should look (a marker's -Z is
## ignored; rotate it about Y: 90 faces right, -90 faces left). spawn() makes
## the enemy again (removing the one it made before); clear() removes it.

@export var enemy_scene: PackedScene
@export var target: CharacterMovement
@export var archetype := EnemyTraits.Archetype.AUTO
## Empty keeps the gun the enemy scene comes with.
@export var weapon: WeaponStats
## 0 = different every time.
@export var random_seed := 0
@export var spawn_on_ready := true

var enemy: CharacterMovement


func _ready() -> void:
	add_to_group(&"enemy_spawns")
	if spawn_on_ready:
		spawn()


func spawn() -> CharacterMovement:
	clear()

	enemy = enemy_scene.instantiate() as CharacterMovement
	if weapon != null:
		(enemy.get_node("Weapon") as Weapon).stats = weapon

	var brain := enemy.get_node("EnemyInput") as EnemyInput
	brain.target = target
	brain.archetype = archetype
	brain.random_seed = random_seed

	enemy.position = position
	enemy.rotation.y = rotation.y
	get_parent().add_child.call_deferred(enemy)
	return enemy


func clear() -> void:
	if is_instance_valid(enemy):
		enemy.queue_free()

	enemy = null
