@tool
class_name ScenarioFoe
extends ScenarioMarker

@export_enum("Grunt", "Rusher", "Gunner", "Flanker", "Hunter", "Sniper") var kind := "Grunt":
	set(value):
		kind = value
		_refresh()
@export var ally := false:
	set(value):
		ally = value
		_refresh()
@export_range(0.0, 60.0, 0.5, "suffix:s") var delay := 0.0:
	set(value):
		delay = value
		_refresh()
@export var stationary := false:
	set(value):
		stationary = value
		_refresh()
@export_range(0.0, 1.0, 0.05) var skill := 0.55
@export_range(0.5, 3.0, 0.05) var toughness := 1.0


func release(menu: SpawnMenu) -> void:
	var level := owner as ScenarioLevel
	var picked := menu.kinds.filter(func(each: SpawnKind) -> bool: return each.label == kind)
	var body := menu.build(
		global_position,
		picked[0],
		SpawnMenu.PLAYER_TEAM if ally else SpawnMenu.ENEMY_TEAM,
	)

	var aim := skill if ally else clampf(skill + level.skill, 0.15, 0.85)
	var brain := body.get_node("EnemyInput") as EnemyInput
	brain.skill_range = Vector2(aim - 0.15, aim + 0.15)
	brain.patrol = _posts()
	brain.stationary = stationary
	(body.get_node("Health") as Health).max_health *= toughness * (1.0 if ally else level.toughness)
	menu.world.add_child(body)


func _posts() -> PackedVector3Array:
	var posts := PackedVector3Array()
	for child in get_children():
		var at := (child as Node3D).global_position
		posts.append(Vector3(at.x, at.y, 0.0))

	return posts


func _caption() -> String:
	var text := kind.to_upper()
	if toughness != 1.0:
		text += " x%.1f" % toughness

	if delay > 0.0:
		text += "  +%ss" % str(delay)

	if stationary:
		text += "  (post)"

	return text


func _color() -> Color:
	return Color(0.35, 0.85, 0.45, 0.5) if ally else Color(0.95, 0.3, 0.25, 0.5)


func _mesh() -> Mesh:
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.25
	capsule.height = _height()
	return capsule


func _height() -> float:
	return 1.75
