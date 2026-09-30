extends CharacterBody3D

@export_group("Speeds")
@export var walk_speed := 1.6
@export var run_speed := 3.2
@export var crouch_speed := 0.8

@export_group("Acceleration")
@export var accel_ground := 9.0
@export var decel_ground := 7.0
@export var accel_air := 3.5
@export var turn_brake := 16.0

@export_group("Jump")
@export var jump_velocity := 4.8
@export var gravity := 9.6
@export var fall_gravity_mult := 1.5

@export_group("Turning")
@export var turn_speed := 4.5
@export var air_turn_scale := 0.25

var desired_speed := 0.0
var desired_dir := 0.0

var _target_yaw := 0.0


func _ready() -> void:
	_target_yaw = rotation.y


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()

	var dir := Input.get_axis("move_left", "move_right")
	var crouching := on_floor and Input.is_action_pressed("crouch")

	var speed := walk_speed
	if crouching:
		speed = crouch_speed
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
	elif Input.is_action_just_pressed("jump") and not crouching:
		velocity.y = jump_velocity

	if absf(dir) > 0.1:
		_target_yaw = PI * 0.5 * signf(dir)

	var turn := turn_speed if on_floor else turn_speed * air_turn_scale
	rotation.y = lerp_angle(rotation.y, _target_yaw, 1.0 - exp(-turn * delta))

	move_and_slide()
