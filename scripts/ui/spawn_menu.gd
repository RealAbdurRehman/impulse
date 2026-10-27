class_name SpawnMenu
extends CanvasLayer

const GROUND := 0.1
const ALLY_SIGHT := 30.0
const ALLY_TEAM := &"player"

@export var player: CharacterMovement
@export var enemy_scene: PackedScene
@export var ally_look: LookStyle
@export var kinds: Array[SpawnKind]
@export var weapons: Array[WeaponStats]

var _place := Callable()
var _group := ButtonGroup.new()

@onready var _armed: Label = %Armed


func _ready() -> void:
	_group.allow_unpress = true
	_group.pressed.connect(_on_picked)
	for kind in kinds:
		_add_pick(%Enemies, kind.label, _drop_character.bind(kind, false))
		_add_pick(%Allies, kind.label, _drop_character.bind(kind, true))

	for stats in weapons:
		_add_pick(%Weapons, AmmoPouch.NAMES[stats.ammo_type].capitalize(), _drop_weapon.bind(stats))

	visible = false


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return

	if key.keycode == KEY_TAB and (visible or player.health.alive):
		_toggle()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE and visible:
		_toggle()
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


func _toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	_camera_reticle().visible = not visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_HIDDEN
	if not visible:
		_disarm()


func _camera_reticle() -> CanvasLayer:
	return get_viewport().get_camera_3d().get_node("Reticle") as CanvasLayer


func _cursor_point() -> Variant:
	var cam := get_viewport().get_camera_3d()
	var mouse := get_viewport().get_mouse_position()
	var plane := Plane(Vector3.BACK, player.plane_z)
	var hit: Variant = plane.intersects_ray(cam.project_ray_origin(mouse), cam.project_ray_normal(mouse))
	if hit == null:
		return null

	var point := hit as Vector3
	return Vector3(point.x, maxf(point.y, GROUND), player.plane_z)


func _add_pick(grid: Container, label: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.toggle_mode = true
	button.button_group = _group
	button.custom_minimum_size = Vector2(170.0, 0.0)
	button.set_meta(&"action", action)
	button.set_meta(&"label", label)
	grid.add_child(button)


func _on_picked(button: BaseButton) -> void:
	if button.button_pressed:
		_place = button.get_meta(&"action")
		_armed.text = "Placing %s" % button.get_meta(&"label")
	else:
		_disarm()


func _disarm() -> void:
	_place = Callable()
	_armed.text = ""
	var held := _group.get_pressed_button()
	if held != null:
		held.button_pressed = false


func _drop_character(at: Vector3, kind: SpawnKind, ally: bool) -> void:
	var body := enemy_scene.instantiate() as CharacterMovement
	(body.get_node("Weapon") as Weapon).stats = kind.weapon

	var brain := body.get_node("EnemyInput") as EnemyInput
	brain.target = player
	brain.archetype = kind.archetype

	var targeter := Targeter.new()
	targeter.brain = brain
	targeter.player = player
	body.add_child(targeter)

	if ally:
		(body.get_node("Health") as Health).team = ALLY_TEAM
		(body.get_node("BodyLook") as BodyLook).style = ally_look
		brain.fair_play = false
		brain.sight_range = ALLY_SIGHT

	body.position = at
	get_parent().add_child(body)


func _drop_weapon(at: Vector3, stats: WeaponStats) -> void:
	WeaponPickup.spawn(get_parent(), stats, stats.magazine_size, Transform3D(Basis.IDENTITY, at), Vector3.ZERO, 0.0)
