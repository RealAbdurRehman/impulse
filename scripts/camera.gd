class_name FollowCamera
extends Camera3D

@export var target: CharacterMovement

@export var follow_speed: float = 7.0
@export var mouse_look_weight: float = 2.8
@export_range(0.3, 1.0) var keep_in_frame: float = 0.8

@export_group("Look ahead")
@export var lookahead_time: float = 0.18
@export var lookahead_max: float = 40
@export var lookahead_speed: float = 4.0

@export var z_distance: float = 10.0
@export var field_of_view: float = 35.0
@export var min_height: float = 0.6

var height_offset: float = 1.0

var fx: CameraFx

var _reticle: Reticle
var _lead := 0.0
var _rig := Vector3.ZERO
var _fov := 0.0
var _fov_before := 0.0


func _ready() -> void:
	fov = field_of_view
	_fov = field_of_view
	_fov_before = field_of_view
	_rig = global_position
	bind(target)


func bind(next: CharacterMovement) -> void:
	if fx != null:
		fx.free()
		_reticle.free()

	target = next

	fx = CameraFx.new()
	fx.name = &"CameraFx"
	fx.target = target
	add_child(fx)

	_reticle = Reticle.new()
	_reticle.name = &"Reticle"
	_reticle.target = target
	add_child(_reticle)


func set_reticle(shown: bool) -> void:
	_reticle.visible = shown


func set_screen_effects(shown: bool) -> void:
	fx.get_node("ScreenFx").visible = shown


func _physics_process(delta: float) -> void:
	var target_pos: Vector3 = (
		target.global_position
		if target.focus == null
		else target \
				.focus \
				.global_position
	)

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var mouse_screen_center: Vector2 = (mouse_pos - (viewport_size / 2.0)) / (viewport_size / 2.0)

	_fov_before = _fov
	_fov = field_of_view * target.aim_zoom * fx.fov_scale
	var half_height := z_distance * tan(deg_to_rad(_fov) * 0.5)
	var reach_x := maxf(
		half_height * viewport_size.x / viewport_size.y * keep_in_frame,
		mouse_look_weight,
	)
	var reach_y := maxf(half_height * keep_in_frame, mouse_look_weight)

	var look := mouse_look_weight * target.aim_look
	var look_offset_x := clampf(mouse_screen_center.x * look, -reach_x, reach_x)
	var look_offset_y := clampf(-mouse_screen_center.y * look, -reach_y, reach_y)

	var lead_target := clampf(target.velocity.x * lookahead_time, -lookahead_max, lookahead_max)
	_lead = lerpf(_lead, lead_target, 1.0 - exp(-lookahead_speed * delta))

	var desired_pos := Vector3(
		target_pos.x + look_offset_x + _lead,
		maxf(target_pos.y + look_offset_y + height_offset, min_height),
		target_pos.z + z_distance,
	)

	_rig = _rig.lerp(desired_pos, 1.0 - exp(-follow_speed * delta))
	global_position = _rig + Vector3(fx.offset.x, fx.offset.y, 0.0)
	rotation = Vector3(0.0, 0.0, fx.roll)


func _process(_delta: float) -> void:
	fov = lerpf(_fov_before, _fov, Engine.get_physics_interpolation_fraction())
