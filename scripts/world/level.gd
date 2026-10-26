class_name Level
extends Node3D

static var run_seed := randi_range(1, 0x7fffffff)

@export var start_chunk: PackedScene
@export var middle_chunks: Array[PackedScene] = []
@export var end_chunk: PackedScene
@export var player: CharacterMovement
@export var enemy_scene: PackedScene
@export var flow: LevelFlow
@export var exit_hold := 5.0
@export var death_delay := 5.0

var built: Array[Chunk] = []


static func new_seed() -> void:
	run_seed = randi_range(1, 0x7fffffff)


func _ready() -> void:
	var game := GameSettings.current
	var run := LevelSettings.current
	game.apply(get_viewport())
	for sun: DirectionalLight3D in find_children("*", "DirectionalLight3D", false, false):
		sun.shadow_enabled = game.shadows()

	(get_node("Camera") as FollowCamera).fx.intensity = game.effects
	AttackTokens.limit = LevelSettings.ATTACKERS[run.difficulty]
	_apply_rules(run)

	if game.indicators:
		add_child(EdgeIndicators.new())

	player.add_child(VisibilityMark.new())

	var lod := EnemyLod.new()
	lod.target = player
	add_child(lod)

	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	_assemble(run, rng)
	Population.fill(built, run, rng)

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
	flow.start(player, zone, run_seed)
	Transition.reveal(get_tree())


func _physics_process(_delta: float) -> void:
	if LevelSettings.current.god_mode:
		player.health.current = player.health.max_health


func _apply_rules(run: LevelSettings) -> void:
	var death := player.get_node("PlayerDeath") as PlayerDeath
	death.restart_delay = death_delay
	death.auto_restart = false

	(player.get_node("PlayerHealing") as PlayerHealing).bandages = run.start_bandages
	(player.get_node("Weapon") as Weapon).infinite_ammo = run.infinite_ammo
	(player.get_node("PlayerStamina") as PlayerStamina).infinite = run.infinite_stamina
	player.health.immortal = run.god_mode


func _assemble(run: LevelSettings, rng: RandomNumberGenerator) -> void:
	var order: Array[PackedScene] = [start_chunk]
	var last := -1
	for i in run.chunk_count:
		var index := rng.randi_range(0, middle_chunks.size() - 1)
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
