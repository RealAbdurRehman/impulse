class_name EditorCamera
extends Camera3D

@export var pan_speed := 1.0
@export var fast_pan := 3.0
@export var zoom_step := 1.18
@export var min_distance := 3.0
@export var max_distance := 48.0
@export var smoothing := 16.0
@export var min_x := -190.0
@export var max_x := 190.0
@export var floor_y := 0.0
@export var ceiling_y := 30.0
@export_range(0.0, 1.0) var view_edge := 0.7

var _subject: CharacterMovement
var _plane := 0.0
var _home := 10.0
var _rig := Vector3.ZERO
var _goal := Vector3.ZERO
var _last := 0


func _init() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	set_process(false)
	set_process_unhandled_input(false)


func begin(from: FollowCamera, subject: CharacterMovement) -> void:
	_subject = subject
	_plane = subject.plane_z
	_home = from.z_distance
	fov = from.field_of_view
	_rig = Vector3(from.global_position.x, from.global_position.y, from.global_position.z - _plane)
	_goal = _rig
	_last = Time.get_ticks_usec()
	_place()
	make_current()
	set_process(true)
	set_process_unhandled_input(true)


func end(to: Camera3D) -> void:
	to.make_current()
	set_process(false)
	set_process_unhandled_input(false)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := minf(float(now - _last) / 1000000.0, 0.1)
	_last = now

	var heading := Vector2(
		_held(KEY_D, KEY_RIGHT) - _held(KEY_A, KEY_LEFT),
		_held(KEY_W, KEY_UP) - _held(KEY_S, KEY_DOWN),
	)
	var speed := pan_speed * _goal.z * (fast_pan if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	_goal = _clamped(_goal + Vector3(heading.x, heading.y, 0.0) * speed * dt)

	_rig = _rig.lerp(_goal, 1.0 - exp(-smoothing * dt))
	_place()


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null and motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		var per_pixel := 2.0 * _rig.z * tan(deg_to_rad(fov) * 0.5) / get_viewport().get_visible_rect().size.y
		var drag := Vector3(-motion.relative.x, motion.relative.y, 0.0) * per_pixel
		_goal = _clamped(_goal + drag)
		_rig += drag
		return

	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var amount := pow(zoom_step, click.factor if click.factor > 0.0 else 1.0)
		_zoom(amount if click.button_index == MOUSE_BUTTON_WHEEL_DOWN else 1.0 / amount)
		return

	var key := event as InputEventKey
	if key == null or not key.pressed:
		return

	if key.keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]:
		_zoom(1.0 / zoom_step)
	elif key.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
		_zoom(zoom_step)
	elif key.keycode == KEY_F and not key.echo:
		_goal = _clamped(Vector3(_subject.global_position.x, _subject.global_position.y + 1.0, _home))


func _zoom(scale_by: float) -> void:
	var next := clampf(_goal.z * scale_by, min_distance, max_distance)
	var view := get_viewport().get_visible_rect().size
	var cursor := (get_viewport().get_mouse_position() - view * 0.5) / (view * 0.5)
	var shift := (_goal.z - next) * tan(deg_to_rad(fov) * 0.5)
	_goal.x += cursor.x * view.x / view.y * shift
	_goal.y -= cursor.y * shift
	_goal.z = next
	_goal = _clamped(_goal)


func _clamped(rig: Vector3) -> Vector3:
	var distance := clampf(rig.z, min_distance, max_distance)
	var reach := distance * tan(deg_to_rad(fov) * 0.5) * view_edge
	return Vector3(
		clampf(rig.x, min_x, max_x),
		clampf(rig.y, floor_y + reach, ceiling_y - reach),
		distance,
	)


func _place() -> void:
	global_position = Vector3(_rig.x, _rig.y, _plane + _rig.z)


func _held(first: Key, second: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(first) or Input.is_physical_key_pressed(second) else 0.0
