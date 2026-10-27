class_name Level
extends Node3D

@export var player: CharacterMovement
@export var enemy_scene: PackedScene
@export var flow: LevelFlow
@export var exit_hold := 5.0
@export var death_delay := 5.0


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
	player.add_child(PlayerStairs.new())
	EnemyNav.reset()
	for bone: PhysicalBone3D in player.find_children("*", "PhysicalBone3D", true, false):
		Door.exempt(bone)

	get_tree().node_added.connect(_on_node_added)

	var lod := EnemyLod.new()
	lod.target = player
	add_child(lod)

	Weathering.fix(get_node("Map"))
	StaticBatch.run(get_node("Map"))
	add_child(Grade.new())

	var start := get_tree().get_first_node_in_group(&"player_start") as Node3D
	player.global_position = start.global_position + Vector3(0.0, 0.1, 0.0)
	player.velocity = Vector3.ZERO

	_arm_enemies(run)

	var zone := get_tree().get_first_node_in_group(&"exit_zone") as ExitZone
	zone.target = player
	zone.hold_time = exit_hold
	flow.start(player, zone)
	Transition.reveal(get_tree())


func _on_node_added(node: Node) -> void:
	if node is PhysicalBone3D:
		Door.exempt(node)


func _physics_process(_delta: float) -> void:
	if LevelSettings.current.god_mode:
		player.health.current = player.health.max_health


func _arm_enemies(run: LevelSettings) -> void:
	var skill: Vector2 = LevelSettings.SKILL[run.difficulty]
	for node in get_tree().get_nodes_in_group(&"enemy_spawns"):
		var spawn := node as EnemySpawn
		if spawn.min_difficulty > run.difficulty:
			spawn.queue_free()
			continue

		spawn.skill_range = skill
		spawn.hostile = not run.peaceful_enemies
		spawn.arm(player, enemy_scene)


func _apply_rules(run: LevelSettings) -> void:
	var death := player.get_node("PlayerDeath") as PlayerDeath
	death.restart_delay = death_delay
	death.auto_restart = false

	(player.get_node("PlayerHealing") as PlayerHealing).bandages = run.start_bandages
	var weapon := player.get_node("Weapon") as Weapon
	weapon.infinite_ammo = run.infinite_ammo
	var pouch := AmmoPouch.new()
	pouch.name = &"AmmoPouch"
	player.add_child(pouch)
	weapon.pouch = pouch
	pouch.add(weapon.stats.ammo_type, run.start_magazines * weapon.stats.magazine_size)
	var loot := PlayerLoot.new()
	loot.name = &"PlayerLoot"
	player.add_child(loot)
	var ammo_hud := AmmoHud.new()
	ammo_hud.loot = loot
	add_child(ammo_hud)
	(player.get_node("PlayerStamina") as PlayerStamina).infinite = run.infinite_stamina
	player.health.immortal = run.god_mode
