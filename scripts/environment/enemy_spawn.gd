class_name EnemySpawn
extends Marker3D

@export var enemy_scene: PackedScene
@export var target: CharacterMovement
@export var archetype := EnemyTraits.Archetype.AUTO
@export var weapon: WeaponStats
@export var patrol_length := 0.0
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
	if patrol_length != 0.0:
		brain.patrol = PackedVector3Array([global_position, global_position + Vector3(patrol_length, 0.0, 0.0)])

	enemy.position = position
	enemy.rotation.y = rotation.y
	get_parent().add_child.call_deferred(enemy)
	return enemy


func clear() -> void:
	if is_instance_valid(enemy):
		enemy.queue_free()

	enemy = null
