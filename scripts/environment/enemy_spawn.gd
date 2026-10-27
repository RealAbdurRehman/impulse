class_name EnemySpawn
extends Marker3D

@export var enemy_scene: PackedScene
@export var target: CharacterMovement
@export var archetype := EnemyTraits.Archetype.AUTO
@export var weapon: WeaponStats
@export var patrol_length := 0.0
@export var skill_range := Vector2(0.25, 0.85)
@export var hostile := true
@export var random_seed := 0
@export var spawn_on_ready := true
@export var spawn_range := 60.0
@export_enum("Easy", "Normal", "Hard") var min_difficulty := 0

var enemy: CharacterMovement

var _left := 0.0


func _ready() -> void:
	add_to_group(&"enemy_spawns")
	set_physics_process(false)
	if spawn_on_ready:
		if _near():
			spawn()
		else:
			set_physics_process(true)


func arm(who: CharacterMovement, scene: PackedScene) -> void:
	target = who
	if enemy_scene == null:
		enemy_scene = scene

	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_left -= delta
	if _left > 0.0:
		return

	_left = 0.5
	if _near():
		spawn()


func _near() -> bool:
	return target == null or global_position.distance_to(target.global_position) < spawn_range


func spawn() -> CharacterMovement:
	set_physics_process(false)
	clear()

	enemy = enemy_scene.instantiate() as CharacterMovement
	if weapon != null:
		(enemy.get_node("Weapon") as Weapon).stats = weapon

	var brain := enemy.get_node("EnemyInput") as EnemyInput
	brain.target = target
	brain.archetype = archetype
	brain.skill_range = skill_range
	brain.hostile = hostile
	brain.random_seed = random_seed
	if patrol_length != 0.0:
		brain.patrol = PackedVector3Array(
			[global_position, global_position + Vector3(patrol_length, 0.0, 0.0)]
		)

	enemy.position = position
	enemy.rotation.y = rotation.y
	get_parent().add_child.call_deferred(enemy)
	return enemy


func clear() -> void:
	if is_instance_valid(enemy):
		enemy.queue_free()

	enemy = null
