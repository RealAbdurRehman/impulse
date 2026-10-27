class_name Sandbox
extends Node3D

const PAUSE := preload("res://scenes/ui/pause_screen.tscn")

@export var player: CharacterMovement
@export var death_delay := 5.0
@export var start_bandages := 4
@export var start_magazines := 4
@export var god_mode := false
@export var infinite_stamina := false

var _lod: EnemyLod


func _ready() -> void:
	var game := GameSettings.current
	game.apply(get_viewport())
	for sun: DirectionalLight3D in find_children("*", "DirectionalLight3D", false, false):
		sun.shadow_enabled = game.shadows()

	(get_node("Camera") as FollowCamera).fx.intensity = game.effects

	if game.indicators:
		add_child(EdgeIndicators.new())

	_lod = EnemyLod.new()
	add_child(_lod)
	_equip(player)
	EnemyNav.reset()
	add_child(Grade.new())
	add_child(PAUSE.instantiate())
	Transition.reveal(get_tree())


func take_over(next: CharacterMovement) -> void:
	var bandages := (player.get_node("PlayerHealing") as PlayerHealing).bandages
	var had := player.get_node("AmmoPouch") as AmmoPouch
	_equip(next)

	(next.get_node("PlayerHealing") as PlayerHealing).bandages = bandages
	var pouch := next.get_node("AmmoPouch") as AmmoPouch
	for type: StringName in had.counts:
		pouch.counts[type] = maxi(pouch.count(type), had.count(type))

	var camera := get_node("Camera") as FollowCamera
	camera.bind(next)
	camera.fx.intensity = GameSettings.current.effects


func _equip(body: CharacterMovement) -> void:
	player = body
	Targeter.player_team = body.health.team
	_apply_rules()
	body.add_child(VisibilityMark.new())
	_lod.target = body
	body.health.died.connect(_on_died)


func _on_died() -> void:
	var editor := get_node("SpawnMenu") as SpawnMenu
	if editor.visible:
		editor.mourn()
		return

	await get_tree().create_timer(death_delay, true, false, true).timeout
	await Transition.dip(get_tree(), editor.open)


func _physics_process(_delta: float) -> void:
	if god_mode:
		player.health.current = player.health.max_health


func _apply_rules() -> void:
	var death := player.get_node("PlayerDeath") as PlayerDeath
	death.restart_delay = death_delay
	death.auto_restart = false

	(player.get_node("PlayerHealing") as PlayerHealing).bandages = start_bandages
	var weapon := player.get_node("Weapon") as Weapon
	var pouch := AmmoPouch.new()
	pouch.name = &"AmmoPouch"
	player.add_child(pouch)
	weapon.pouch = pouch
	pouch.add(weapon.stats.ammo_type, start_magazines * weapon.stats.magazine_size)
	var loot := PlayerLoot.new()
	loot.name = &"PlayerLoot"
	player.add_child(loot)
	(player.get_node("PlayerStamina") as PlayerStamina).infinite = infinite_stamina
	player.health.immortal = god_mode
