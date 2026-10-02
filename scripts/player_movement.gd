extends CharacterBody3D

@export_group("Speeds")
@export var walk_speed := 1.6
@export var run_speed := 3.2
@export var crouch_speed := 0.8

@export_range(0.2, 1.0) var backpedal_speed_mult := 0.7

@export_group("Acceleration")
@export var accel_air := 3.5
@export var accel_ground := 9.0
@export var decel_ground := 7.0

@export var turn_brake := 10.0

@export_group("Jump")
@export var gravity := 9.6
@export var jump_velocity := 5.2
@export var fall_gravity_mult := 1.5

@export var coyote_time := 0.10
@export var jump_buffer_time := 0.10

@export_range(0.2, 1.0) var jump_cut := 0.5

@export_group("Aiming")
@export var face_mouse := true

@export var flip_speed := 5.0
@export var air_flip_scale := 1.0

@export var aim_deadzone := 0.35
@export var aim_origin_height := 1.35

@export var camera: Camera3D
@export var hide_system_cursor := false

var desired_speed := 0.0
var desired_dir := 0.0

var facing := 1

var moving_backward := false

var aim_point := Vector3.ZERO
var aim_direction := Vector3.RIGHT
var aim_pitch := 0.0

var _target_yaw := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0


func _ready() -> void:
	_target_yaw = rotation.y
	facing = 1 if sin(rotation.y) >= 0.0 else -1

	if hide_system_cursor:
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()

	if on_floor:
		_coyote = coyote_time
	else:
		_coyote = maxf(0.0, _coyote - delta)

	if Input.is_action_just_pressed("jump"):
		_jump_buffer = jump_buffer_time
	else:
		_jump_buffer = maxf(0.0, _jump_buffer - delta)

	var dir := Input.get_axis("move_left", "move_right")
	var crouching := on_floor and Input.is_action_pressed("crouch")

	var aimed := false

	if face_mouse:
		aimed = _update_aim()

	if not aimed and absf(dir) > 0.1:
		facing = 1 if dir > 0.0 else -1

	moving_backward = absf(dir) > 0.1 and int(signf(dir)) != facing

	var speed := walk_speed
	if crouching:
		speed = crouch_speed
	elif moving_backward:
		speed = walk_speed * backpedal_speed_mult
	elif Input.is_action_pressed("sprint"):
		speed = run_speed

	desired_dir = dir
	desired_speed = absf(dir) * speed

	var target_vx := dir * speed

	var accel: float
	if not on_floor:
		accel = accel_air
	elif absf(dir) < 0.1:
		accel = decel_ground
	elif signf(dir) != signf(velocity.x) and absf(velocity.x) > 0.1:
		accel = turn_brake
	else:
		accel = accel_ground

	velocity.x = move_toward(velocity.x, target_vx, accel * delta)
	velocity.z = 0.0

	if not on_floor:
		var g := gravity * (fall_gravity_mult if velocity.y < 0.0 else 1.0)
		velocity.y -= g * delta

	if _jump_buffer > 0.0 and _coyote > 0.0 and not crouching:
		velocity.y = jump_velocity

		_jump_buffer = 0.0
		_coyote = 0.0

	if jump_cut < 1.0 and Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y *= jump_cut

	_target_yaw = PI * 0.5 * float(facing)
	var turn := flip_speed if on_floor else flip_speed * air_flip_scale

	rotation.y = lerp_angle(rotation.y, _target_yaw, 1.0 - exp(-turn * delta))

	move_and_slide()


func _update_aim() -> bool:
	var cam := camera if camera != null else get_viewport().get_camera_3d()
	if cam == null:
		return false

	var mouse := get_viewport().get_mouse_position()
	var ray_from := cam.project_ray_origin(mouse)
	var ray_dir := cam.project_ray_normal(mouse)

	var plane := Plane(Vector3.BACK, global_position.z)
	var hit: Variant = plane.intersects_ray(ray_from, ray_dir)
	if hit == null:
		return false

	aim_point = hit

	var dx := aim_point.x - global_position.x
	if absf(dx) > aim_deadzone:
		facing = 1 if dx > 0.0 else -1

	var shoulder := global_position + Vector3.UP * aim_origin_height
	var to_aim := aim_point - shoulder
	if to_aim.length_squared() > 0.0001:
		aim_direction = to_aim.normalized()
		aim_pitch = atan2(to_aim.y, maxf(absf(to_aim.x), 0.001))

	return true
