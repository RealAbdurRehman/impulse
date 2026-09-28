extends Camera3D

@export var target: Node3D

@export var follow_speed: float = 8.0
@export var mouse_look_weight: float = 1.5

@export var z_distance: float = 12.0
@export var field_of_view: float = 35.0

var height_offset: float = 1.0


func _ready() -> void:
	projection = Camera3D.PROJECTION_PERSPECTIVE
	fov = field_of_view


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return

	var target_pos: Vector3 = target.global_position

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var mouse_screen_center: Vector2 = (mouse_pos - (viewport_size / 2.0)) / (viewport_size / 2.0)

	var look_offset_x := mouse_screen_center.x * mouse_look_weight
	var look_offset_y := -mouse_screen_center.y * mouse_look_weight

	var desired_pos := Vector3(
		target_pos.x + look_offset_x,
		target_pos.y + look_offset_y + height_offset,
		target_pos.z + z_distance,
	)

	global_position = global_position.lerp(desired_pos, follow_speed * delta)
	rotation_degrees = Vector3.ZERO
