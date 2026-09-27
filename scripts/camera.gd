extends Camera3D

@export var target: Node3D

@export var follow_speed: float = 8.0
@export var mouse_look_weight: float = 2.0

@export var z_distance: float = 18.0
@export var field_of_view: float = 35.0

var height_offset: float = 1.0

func _ready() -> void:
	projection = Camera3D.PROJECTION_PERSPECTIVE
	fov = field_of_view

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	
	var target_pos: Vector3 = target.global_position
	
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var mouse_screen_center: Vector2 = (mouse_pos - (viewport_size / 2.0)) / (viewport_size / 2.0)
	
	var mouse_offset := Vector3(
		mouse_screen_center.x * mouse_look_weight * (size / 2.0),
		-mouse_screen_center.y * mouse_look_weight * (size / 2.0),
		0.0
	)
	
	var desired_pos := Vector3(
		target_pos.x + mouse_offset.x,
		target_pos.y + mouse_offset.y + height_offset,
		target_pos.z + z_distance
	)
	
	global_position = global_position.lerp(desired_pos, follow_speed * delta)
	rotation_degrees = Vector3.ZERO
