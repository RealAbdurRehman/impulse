class_name PlayerInput
extends ActorInput

@export var hide_system_cursor := false

var suspended := false

@onready var _body := get_parent() as Node3D


func _ready() -> void:
	if hide_system_cursor:
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN


func poll() -> void:
	if suspended:
		release()
		return

	move = Input.get_axis("move_left", "move_right")
	crouch = Input.is_action_pressed("crouch")
	sprint = Input.is_action_pressed("sprint")
	jump = Input.is_action_pressed("jump")
	fire = Input.is_action_pressed("shoot")
	aim = Input.is_action_pressed("aim")
	reload = Input.is_action_pressed("reload")
	fire_mode = Input.is_action_pressed("fire_mode")
	interact = Input.is_action_pressed("interact")
	heal = Input.is_action_pressed("heal")

	_aim_at_mouse()


func _aim_at_mouse() -> void:
	var cam := get_viewport().get_camera_3d()
	var mouse := get_viewport().get_mouse_position()
	var plane := Plane(Vector3.BACK, _body.global_position.z)

	var hit: Variant = plane.intersects_ray(cam.project_ray_origin(mouse), cam.project_ray_normal(mouse))
	has_aim = hit != null
	if has_aim:
		aim_point = hit
