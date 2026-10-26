class_name Level
extends Node3D

static var rolled_seed := 0

@export var settings: LevelSettings
@export var start_chunk: PackedScene
@export var middle_chunks: Array[PackedScene] = []
@export var end_chunk: PackedScene
@export var player: CharacterMovement
@export var enemy_scene: PackedScene
@export var flow: LevelFlow

@export var start_bandages := 4
@export var exit_hold := 5.0
@export var death_delay := 5.0

var seed_used := 0
var built: Array[Chunk] = []


static func new_seed() -> void:
	rolled_seed = 0


func _ready() -> void:
	AttackTokens.limit = LevelSettings.ATTACKERS[settings.difficulty]
	(player.get_node("PlayerHealing") as PlayerHealing).bandages = start_bandages

	var death := player.get_node("PlayerDeath") as PlayerDeath
	death.restart_delay = death_delay
	death.auto_restart = false

	add_child(EdgeIndicators.new())
	player.add_child(VisibilityMark.new())

	var lod := EnemyLod.new()
	lod.target = player
	add_child(lod)

	if settings.level_seed != 0:
		seed_used = settings.level_seed
	else:
		if rolled_seed == 0:
			rolled_seed = randi_range(1, 0x7fffffff)

		seed_used = rolled_seed

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_used
	_assemble(rng)
	Population.fill(built, settings, rng)

	player.global_position = built[0].entry_point() + Vector3(1.5, 0.1, 0.0)
	player.velocity = Vector3.ZERO

	for chunk in built:
		for spawn in chunk.spawns():
			spawn.arm(player, enemy_scene)

	var zone := ExitZone.new()
	zone.target = player
	zone.hold_time = exit_hold
	zone.position = built[-1].objective().global_position
	add_child(zone)

	flow.start(player, zone, seed_used)


func _assemble(rng: RandomNumberGenerator) -> void:
	var order: Array[PackedScene] = [start_chunk]
	var last := -1
	for i in settings.chunk_count:
		var index := 0
		if middle_chunks.size() > 1:
			index = rng.randi_range(0, middle_chunks.size() - 1)
			if index == last:
				index = (index + 1) % middle_chunks.size()

		last = index
		order.append(middle_chunks[index])

	order.append(end_chunk)
	for scene in order:
		var chunk := scene.instantiate() as Chunk
		add_child(chunk)
		if not built.is_empty():
			chunk.place_after(built[-1])

		built.append(chunk)
