class_name SpawnMenu
extends CanvasLayer

const GROUND := 0.1
const CEILING := 28.0
const PLAYER_TEAM := &"player"
const ENEMY_TEAM := &"enemy"
const MARK_COLOR := Color(1.0, 0.36, 0.3)
const POSSESS_COLOR := Color(0.45, 0.85, 0.5)
const MARK_PAD := 6.0

@export var enemy_scene: PackedScene
@export var ally_look: LookStyle
@export var kinds: Array[SpawnKind]
@export var weapons: Array[WeaponStats]
@export var props: Array[PackedScene]

var world: Sandbox
var player: CharacterMovement:
	get:
		return world.player

var _place := Callable()
var _group := ButtonGroup.new()
var _follow: FollowCamera
var _view: EditorCamera
var _delete: Button
var _possess: Button
var _hover: Node3D

@onready var _armed: Label = %Armed
@onready var _run: Button = %Run
@onready var _notice: Label = %Notice
@onready var _panel: Control = $Panel
@onready var _marker: Control = %Marker


func _ready() -> void:
	world = get_parent() as Sandbox
	_follow = world.get_node("Camera") as FollowCamera
	_view = EditorCamera.new()
	add_child(_view)

	_group.allow_unpress = true
	_group.pressed.connect(_on_picked)
	for kind in kinds:
		_add_pick(%Enemies, kind.label, _drop_character.bind(kind, false), "Placing %s" % kind.label)
		_add_pick(%Allies, kind.label, _drop_character.bind(kind, true), "Placing %s" % kind.label)

	for stats in weapons:
		var label: String = AmmoPouch.NAMES[stats.ammo_type].capitalize()
		_add_pick(%Weapons, label, _drop_weapon.bind(stats), "Placing %s" % label)

	for scene in props:
		var label := scene.resource_path.get_file().get_basename().replace("modularkit_", "").replace("_", " ").capitalize()
		_add_pick(%PropGrid, label, _drop_prop.bind(scene), "Placing %s" % label)

	_delete = _add_pick(%Tools, "Delete", _delete_at, "Click something to delete it")
	_possess = _add_pick(%Tools, "Possess", _possess_at, "Click a character to take control")
	%ClearEnemies.pressed.connect(_clear.bind(false))
	%ClearAllies.pressed.connect(_clear.bind(true))
	%ClearWeapons.pressed.connect(_clear_weapons)
	%ClearProps.pressed.connect(_clear_props)
	_marker.draw.connect(_paint)
	_run.toggled.connect(_set_running)

	visible = false


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return

	if key.keycode == KEY_TAB and player.health.alive:
		if visible:
			close()
		else:
			open()
	elif key.keycode == KEY_SPACE and visible:
		_run.button_pressed = not _run.button_pressed
	elif key.keycode == KEY_X and visible:
		_toggle_tool(_delete)
	elif key.keycode == KEY_P and visible:
		_toggle_tool(_possess)
	else:
		return

	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if not visible or click == null or not click.pressed:
		return

	if click.button_index == MOUSE_BUTTON_RIGHT:
		_disarm()
	elif click.button_index == MOUSE_BUTTON_LEFT and _place.is_valid():
		var at: Variant = _cursor_point()
		if at != null:
			_place.call(at)


func _process(_delta: float) -> void:
	var over: Node3D = null
	var aiming := _delete.button_pressed or _possess.button_pressed
	if aiming and not _panel.get_global_rect().has_point(get_viewport().get_mouse_position()):
		var at: Variant = _cursor_point()
		if at != null:
			over = EditorPick.at(get_tree(), at, _delete.button_pressed, player)

	if over != null or _hover != null:
		_hover = over
		_marker.queue_redraw()


func open() -> void:
	visible = true
	_follow.set_reticle(false)
	_follow.set_screen_effects(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(player.get_node("PlayerInput") as PlayerInput).suspended = true
	_view.begin(_follow, player)
	_set_running(false)
	if not player.health.alive:
		mourn()


func close() -> void:
	visible = false
	_follow.set_reticle(true)
	_follow.set_screen_effects(true)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	(player.get_node("PlayerInput") as PlayerInput).suspended = false
	_view.end(_follow)
	_set_running(true)
	_notice.visible = false
	_disarm()


func mourn() -> void:
	player.get_node("PlayerSlowMotion").free()
	(player.get_node("PlayerHud") as CanvasLayer).visible = false
	_notice.visible = true


func spawn(at: Vector3, kind: SpawnKind, team: StringName) -> CharacterMovement:
	var body := enemy_scene.instantiate() as CharacterMovement
	(body.get_node("Weapon") as Weapon).stats = kind.weapon

	var brain := body.get_node("EnemyInput") as EnemyInput
	brain.target = player
	brain.archetype = kind.archetype

	var targeter := Targeter.new()
	targeter.brain = brain
	targeter.player = player
	body.add_child(targeter)

	(body.get_node("Health") as Health).team = team
	if team == PLAYER_TEAM:
		(body.get_node("BodyLook") as BodyLook).style = ally_look

	Roster.align(brain, player.health.team)
	body.position = at
	world.add_child(body)
	return body


func _set_running(on: bool) -> void:
	_run.set_pressed_no_signal(on)
	_run.text = "World running (Space)" if on else "World frozen (Space)"
	get_tree().paused = not on


func _cursor_point() -> Variant:
	var cam := get_viewport().get_camera_3d()
	var mouse := get_viewport().get_mouse_position()
	var plane := Plane(Vector3.BACK, player.plane_z)
	var hit: Variant = plane.intersects_ray(cam.project_ray_origin(mouse), cam.project_ray_normal(mouse))
	if hit == null:
		return null

	var point := hit as Vector3
	return Vector3(point.x, clampf(point.y, GROUND, CEILING), player.plane_z)


func _add_pick(grid: Container, label: String, action: Callable, status: String) -> Button:
	var button := Button.new()
	button.text = label
	button.toggle_mode = true
	button.button_group = _group
	button.custom_minimum_size = Vector2(170.0, 0.0)
	button.set_meta(&"action", action)
	button.set_meta(&"status", status)
	grid.add_child(button)
	return button


func _on_picked(button: BaseButton) -> void:
	if button.button_pressed:
		_place = button.get_meta(&"action")
		_armed.text = button.get_meta(&"status")
	else:
		_disarm()


func _toggle_tool(button: Button) -> void:
	if button.button_pressed:
		_disarm()
	else:
		_arm(button)


func _arm(button: Button) -> void:
	for other in _group.get_buttons():
		other.set_pressed_no_signal(other == button)

	_on_picked(button)


func _disarm() -> void:
	_place = Callable()
	_armed.text = ""
	var held := _group.get_pressed_button()
	if held != null:
		held.button_pressed = false

	_forget_hover()


func _forget_hover() -> void:
	_hover = null
	_marker.queue_redraw()


func _drop_character(at: Vector3, kind: SpawnKind, ally: bool) -> void:
	var mine := player.health.team
	spawn(at, kind, mine if ally else (ENEMY_TEAM if mine == PLAYER_TEAM else PLAYER_TEAM))


func _drop_weapon(at: Vector3, stats: WeaponStats) -> void:
	WeaponPickup.spawn(world, stats, stats.magazine_size, Transform3D(Basis.IDENTITY, at), Vector3.ZERO, 0.0)


func _drop_prop(at: Vector3, scene: PackedScene) -> void:
	var prop := scene.instantiate() as Node3D
	world.add_child(prop)
	prop.global_position = at


func _delete_at(at: Vector3) -> void:
	var found := EditorPick.at(get_tree(), at, true, player)
	if found is CharacterMovement:
		Roster.remove(get_tree(), found as CharacterMovement, player)
	elif found != null:
		found.queue_free()

	_forget_hover()


func _possess_at(at: Vector3) -> void:
	var found := EditorPick.at(get_tree(), at, false, player) as CharacterMovement
	if found != null:
		Possession.take(self, found)
		close()


func _clear(allies: bool) -> void:
	Roster.clear(get_tree(), player, allies)
	_forget_hover()


func _clear_weapons() -> void:
	for group in EditorPick.ITEMS:
		for node in get_tree().get_nodes_in_group(group):
			node.queue_free()

	_forget_hover()


func _clear_props() -> void:
	for node in get_tree().get_nodes_in_group(EditorPick.PROPS):
		node.queue_free()

	_forget_hover()


func _paint() -> void:
	if not is_instance_valid(_hover):
		return

	var camera := get_viewport().get_camera_3d()
	var rect := Rect2()
	var first := true
	for point in EditorPick.corners(_hover):
		var seen := camera.unproject_position(point)
		rect = Rect2(seen, Vector2.ZERO) if first else rect.expand(seen)
		first = false

	rect = rect.grow(MARK_PAD)
	var color := POSSESS_COLOR if _possess.button_pressed else MARK_COLOR
	_marker.draw_rect(rect, Color(color, 0.14))
	_marker.draw_rect(rect, color, false, 2.0)
