class_name TestRange
extends Node3D
## A level for trying out enemies: zones for open ground, cover, stairs and a
## catwalk, an obstacle course and a ledge, enemies standing at stations, and
## keys to put more of any kind where the mouse is. A heads-up list of the keys
## is on screen (F1 hides it).
##
## 1 to 6   spawn a grunt, rusher, suppressor, cautious, marksman or flanker
## 7        spawn a squad of three        8   spawn a hunter (tracks you once it has found you)
## Z / X    gun for what you spawn: auto (suits the type), pistol, rifle, shotgun, sniper
## K        kill all enemies        Delete   remove all enemies     Backspace   respawn the stations
## H        heal                    Y        god mode               T           enemies ignore you
## V        labels over enemies     N        map of where enemies can go and how (white walk, yellow jump, red drop)
## J        enemies always know where you are and come for you (over gaps and boxes too)
## G        fair play on/off: on, enemies only shoot once the camera shows them (snipers: after their laser)

const WEAPONS := ["auto", "g17", "m4a1", "rem870", "l96a1"]

## What "auto" gives each type, picked at random from the list.
const AUTO_GUNS := {
	EnemyTraits.Archetype.GRUNT: ["g17", "m4a1"],
	EnemyTraits.Archetype.RUSHER: ["rem870", "m4a1"],
	EnemyTraits.Archetype.SUPPRESSOR: ["m4a1"],
	EnemyTraits.Archetype.CAUTIOUS: ["m4a1", "g17"],
	EnemyTraits.Archetype.MARKSMAN: ["l96a1"],
	EnemyTraits.Archetype.FLANKER: ["m4a1", "rem870"],
	EnemyTraits.Archetype.HUNTER: ["m4a1", "rem870"],
}

const SPAWN_KEYS := {
	KEY_1: EnemyTraits.Archetype.GRUNT,
	KEY_2: EnemyTraits.Archetype.RUSHER,
	KEY_3: EnemyTraits.Archetype.SUPPRESSOR,
	KEY_4: EnemyTraits.Archetype.CAUTIOUS,
	KEY_5: EnemyTraits.Archetype.MARKSMAN,
	KEY_6: EnemyTraits.Archetype.FLANKER,
	KEY_8: EnemyTraits.Archetype.HUNTER,
}

@export var enemy_scene: PackedScene
@export var player: CharacterMovement
@export var camera: Camera3D
## Falling below this height kills whoever it is.
@export var void_height := -8.0
## Seconds before the level restarts after the player dies.
@export var restart_delay := 2.0

var _gun := 0
var _god := false
var _peaceful := false
var _hunting := false
var _fair := true
var _labels_on := true
var _hud_on := true

var _hud: Label
var _labels := { }
var _tick := 0.0
var _nav_lines: MeshInstance3D


func _ready() -> void:
	(player.get_node("PlayerDeath") as PlayerDeath).restart_delay = restart_delay
	_hud = Label.new()
	_hud.position = Vector2(14.0, 10.0)
	_hud.add_theme_font_size_override("font_size", 15)
	_hud.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_hud.add_theme_constant_override("shadow_offset_x", 1)
	_hud.add_theme_constant_override("shadow_offset_y", 1)

	var layer := CanvasLayer.new()
	layer.add_child(_hud)
	add_child(layer)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return

	var code := key.physical_keycode
	if SPAWN_KEYS.has(code):
		_spawn_at_cursor(SPAWN_KEYS[code])
		return

	match code:
		KEY_7:
			_spawn_squad()
		KEY_Z:
			_gun = posmod(_gun - 1, WEAPONS.size())
		KEY_X:
			_gun = posmod(_gun + 1, WEAPONS.size())
		KEY_K:
			_kill_all()
		KEY_DELETE:
			_clear_all()
		KEY_BACKSPACE:
			_respawn_stations()
		KEY_H:
			_heal()
		KEY_Y:
			_god = not _god
			_heal()
		KEY_T:
			_peaceful = not _peaceful
			_apply_hostility()
		KEY_J:
			_hunting = not _hunting
			_apply_hostility()
		KEY_G:
			_fair = not _fair
			_apply_hostility()
		KEY_V:
			_labels_on = not _labels_on
		KEY_N:
			_toggle_nav()
		KEY_F1:
			_hud_on = not _hud_on


func _physics_process(_delta: float) -> void:
	_fall_check()


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return

	_tick = 0.2
	_update_labels()
	_hud.visible = _hud_on
	_hud.text = _hud_text()


## Where the mouse points on the ground (or a platform) in the play plane.
func _cursor_spot() -> Vector3:
	var mouse := get_viewport().get_mouse_position()
	var plane := Plane(Vector3.BACK, 0.0)
	var hit: Variant = plane.intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	if hit == null:
		return Vector3.INF

	var from: Vector3 = hit + Vector3.UP * 0.4
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 30.0, 1)
	var floor_hit := get_world_3d().direct_space_state.intersect_ray(query)
	return Vector3.INF if floor_hit.is_empty() else floor_hit.position


func _spawn_at_cursor(archetype: EnemyTraits.Archetype) -> void:
	var spot := _cursor_spot()
	if spot != Vector3.INF:
		_spawn(archetype, spot)


func _spawn_squad() -> void:
	var spot := _cursor_spot()
	if spot == Vector3.INF:
		return

	var kinds: Array[EnemyTraits.Archetype] = [
		EnemyTraits.Archetype.SUPPRESSOR,
		EnemyTraits.Archetype.RUSHER,
		EnemyTraits.Archetype.FLANKER,
	]
	for i in kinds.size():
		_spawn(kinds[i], spot + Vector3(float(i) * 2.2, 0.0, 0.0))


func _spawn(archetype: EnemyTraits.Archetype, at: Vector3) -> void:
	var enemy := enemy_scene.instantiate() as CharacterMovement
	var gun: String = WEAPONS[_gun]
	if gun == "auto":
		var options: Array = AUTO_GUNS[archetype]
		gun = options[randi() % options.size()]

	(enemy.get_node("Weapon") as Weapon).stats = load("res://scenes/weapons/%s_stats.tres" % gun) as WeaponStats

	var brain := enemy.get_node("EnemyInput") as EnemyInput
	brain.target = player
	brain.archetype = archetype
	brain.hostile = not _peaceful
	brain.hunt = _hunting
	brain.fair_play = _fair

	enemy.position = at
	enemy.rotation.y = -PI * 0.5 if player.global_position.x < at.x else PI * 0.5
	add_child(enemy)


func _enemies() -> Array[EnemyInput]:
	var found: Array[EnemyInput] = []
	for node in get_tree().get_nodes_in_group(&"enemies"):
		found.append(node as EnemyInput)

	return found


func _kill_all() -> void:
	for brain in _enemies():
		if brain.health.alive:
			var bone := brain.health.ragdoll.get_child(0) as PhysicalBone3D
			brain.health.hit(1000.0, bone.global_position, Vector3.RIGHT, bone, 20.0)


func _clear_all() -> void:
	for spawn in get_tree().get_nodes_in_group(&"enemy_spawns"):
		(spawn as EnemySpawn).enemy = null

	for brain in _enemies():
		brain.get_parent().queue_free()


func _respawn_stations() -> void:
	_clear_all()
	for node in find_children("*", "EnemySpawn", true, false):
		(node as EnemySpawn).spawn()

	_apply_hostility()


func _heal() -> void:
	var health := player.get_node("Health") as Health
	health.max_health = 1000000.0 if _god else 100.0
	health.current = health.max_health


func _apply_hostility() -> void:
	for brain in _enemies():
		brain.hostile = not _peaceful
		brain.hunt = _hunting
		brain.fair_play = _fair


func _fall_check() -> void:
	if player.global_position.y < void_height:
		var health := player.get_node("Health") as Health
		if health.alive:
			var bone := health.ragdoll.get_child(0) as PhysicalBone3D
			health.hit(100000.0, bone.global_position, Vector3.UP, bone)

	for brain in _enemies():
		if brain.health.alive and brain.get_parent().global_position.y < void_height:
			var bone := brain.health.ragdoll.get_child(0) as PhysicalBone3D
			brain.health.hit(100000.0, bone.global_position, Vector3.UP, bone)


func _update_labels() -> void:
	for brain in _enemies():
		var body := brain.get_parent() as Node3D
		var id := body.get_instance_id()
		var label: Label3D = _labels.get(id)
		if label == null:
			label = Label3D.new()
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true
			label.fixed_size = false
			label.pixel_size = 0.0045
			label.font_size = 28
			label.outline_size = 8
			label.position = Vector3(0.0, 2.35, 0.0)
			body.add_child(label)
			_labels[id] = label

		label.visible = _labels_on and brain.health.alive
		if label.visible:
			label.text = brain.describe()


func _hud_text() -> String:
	var health := player.get_node("Health") as Health
	var alive := 0
	for brain in _enemies():
		alive += int(brain.health.alive)

	var lines := PackedStringArray([
		"TEST RANGE      you %d hp%s%s%s      enemies alive %d      spawn gun: %s" % [
			roundi(health.current) if not _god else 999,
			"  GOD" if _god else "",
			"  (enemies ignore you)" if _peaceful else ("  (enemies hunt you)" if _hunting else ""),
			"" if _fair else "  (fair play off)",
			alive,
			String(WEAPONS[_gun]).to_upper(),
		],
		"1 grunt  2 rusher  3 suppressor  4 cautious  5 marksman  6 flanker  7 squad  8 hunter   (at the mouse)",
		"Z/X gun   K kill all   Del remove all   Backspace restart stations   H heal   Y god   T ignore me   J hunt me   G fair play",
		"V labels   N routes   F1 hide this     A/D move  Space jump  C crouch  E pick up  R reload",
	])
	return "\n".join(lines)


func _toggle_nav() -> void:
	if _nav_lines == null:
		_nav_lines = _build_nav_lines()
		add_child(_nav_lines)
	else:
		_nav_lines.visible = not _nav_lines.visible


## Every link of the map enemies plan routes on, as lines.
func _build_nav_lines() -> MeshInstance3D:
	var nav := EnemyNav.of(player, 1, 120.0)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	var colours := [Color(0.85, 0.9, 1.0), Color(1.0, 0.85, 0.2), Color(1.0, 0.3, 0.25)]
	for id in nav.xs.size():
		var from := Vector3(nav.xs[id], nav.ys[id] + 0.05, 0.3)
		for link: Array in nav.links[id]:
			var to := Vector3(nav.xs[link[0]], nav.ys[link[0]] + 0.05, 0.3)
			mesh.surface_set_color(colours[link[1]])
			mesh.surface_add_vertex(from)
			mesh.surface_set_color(colours[link[1]])
			mesh.surface_add_vertex(to)

	mesh.surface_end()

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true

	var lines := MeshInstance3D.new()
	lines.mesh = mesh
	lines.material_override = material
	return lines
