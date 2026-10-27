class_name Sandbox
extends Node3D

const MENU := "res://scenes/ui/menu.tscn"

@export var player: CharacterMovement
@export var death_delay := 5.0
@export var start_bandages := 4
@export var start_magazines := 4
@export var god_mode := false
@export var infinite_stamina := false


func _ready() -> void:
	var game := GameSettings.current
	game.apply(get_viewport())
	for sun: DirectionalLight3D in find_children("*", "DirectionalLight3D", false, false):
		sun.shadow_enabled = game.shadows()

	(get_node("Camera") as FollowCamera).fx.intensity = game.effects
	_apply_rules()

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
	add_child(Grade.new())

	player.health.died.connect(_on_died)
	Transition.reveal(get_tree())


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		Transition.go(get_tree(), MENU)


func _on_died() -> void:
	await get_tree().create_timer(death_delay, true, false, true).timeout
	Transition.go(get_tree(), MENU)


func _on_node_added(node: Node) -> void:
	if node is PhysicalBone3D:
		Door.exempt(node)


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
	var ammo_hud := AmmoHud.new()
	ammo_hud.loot = loot
	add_child(ammo_hud)
	(player.get_node("PlayerStamina") as PlayerStamina).infinite = infinite_stamina
	player.health.immortal = god_mode
