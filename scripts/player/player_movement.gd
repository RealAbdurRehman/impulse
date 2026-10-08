extends Node3D

@export_group("Speeds")
@export var walk_speed := 0.95
@export var run_speed := 2.0
@export var crouch_speed := 0.8

@export_range(0.2, 1.0) var backpedal_speed_mult := 0.7

@export_group("Acceleration")
@export var accel_ground := 2.2
@export var decel_ground := 3.5

@export var turn_brake := 5.0
@export var accel_air := 2.0

@export_group("Root Follow")
@export var follow_y := 9.0

@export_group("World Probes")
@export_flags_3d_physics var ground_mask: int = 1

@export var max_step_up := 0.6
@export var wall_check_distance := 0.45
@export var head_check_height := 1.5

@export var fall_off_height := 0.9
@export var blocked_brake := 12.0

@export_group("Stairs")
@export var stairs_speed := 1.4

@export var stairs_slope := 0.2
@export var stairs_probe := 0.5

@export_group("Jump")
@export var gravity := 9.6
@export var jump_velocity := 4.4
@export var fall_gravity_mult := 1.5

@export var coyote_time := 0.10
@export var jump_buffer_time := 0.10

@export_range(0.2, 1.0) var jump_cut := 0.5

@export_group("Aiming")
@export var face_mouse := true

@export var flip_speed := 4.5
@export var air_flip_scale := 1.0

@export var aim_deadzone := 0.35
@export var aim_origin_height := 1.35

@export var camera: Camera3D
@export var hide_system_cursor := false

@export_group("Push")
@export var push_decay := 1.5

var desired_speed := 0.0
var desired_dir := 0.0

var move_speed := 0.0
var move_dir := 0.0

var facing := 1
var moving_backward := false

var grounded := true
var velocity := Vector3.ZERO

var plane_z := 0.0

var push := 0.0

var aim_point := Vector3.ZERO
var aim_pitch := 0.0

var _stairs_amt := 0.0
var _target_yaw := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _vy := 0.0


func _ready() -> void:
	plane_z = global_position.z
	facing = 1 if sin(rotation.y) >= 0.0 else -1
	_target_yaw = PI * 0.5 * float(facing)
	rotation.y = _target_yaw

	if hide_system_cursor:
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN


func is_on_floor() -> bool:
	return grounded


func push_back(distance: float) -> void:
	push -= float(facing) * distance


func _physics_process(delta: float) -> void:
	push *= exp(-push_decay * delta)

	if grounded:
		_coyote = coyote_time
	else:
		_coyote = maxf(0.0, _coyote - delta)

	if Input.is_action_just_pressed("jump"):
		_jump_buffer = jump_buffer_time
	else:
		_jump_buffer = maxf(0.0, _jump_buffer - delta)

	var dir := Input.get_axis("move_left", "move_right")

	var pushed := absf(dir) < 0.1 and absf(push) > 0.1
	if pushed:
		dir = clampf(push, -1.0, 1.0)

	var crouching := grounded and Input.is_action_pressed("crouch")

	var aimed := false
	if face_mouse:
		aimed = _update_aim()

	if not aimed and not pushed and absf(dir) > 0.1:
		facing = 1 if dir > 0.0 else -1

	moving_backward = absf(dir) > 0.1 and int(signf(dir)) != facing

	var speed := walk_speed
	if crouching:
		speed = crouch_speed
	elif moving_backward:
		speed = walk_speed * backpedal_speed_mult
	elif Input.is_action_pressed("sprint"):
		speed = run_speed

	var want_dir := int(signf(dir)) if absf(dir) > 0.1 else 0
	var blocked := want_dir != 0 and _is_blocked(want_dir)

	_update_stairs(want_dir, delta)
	speed = lerpf(speed, minf(speed, stairs_speed), _stairs_amt)

	if blocked:
		desired_dir = 0.0
		desired_speed = 0.0
		_ramp_intent(0, 0.0, true, delta)
	else:
		desired_dir = dir
		desired_speed = absf(dir) * speed
		_ramp_intent(want_dir, desired_speed, false, delta)

	if _jump_buffer > 0.0 and _coyote > 0.0 and not crouching:
		_vy = jump_velocity
		grounded = false

		_jump_buffer = 0.0
		_coyote = 0.0

	if jump_cut < 1.0 and Input.is_action_just_released("jump") and not grounded and _vy > 0.0:
		_vy *= jump_cut

	_target_yaw = PI * 0.5 * float(facing)
	var turn := flip_speed if grounded else flip_speed * air_flip_scale

	rotation.y = lerp_angle(rotation.y, _target_yaw, 1.0 - exp(-turn * delta))

	if grounded:
		_advance_grounded(delta)
		_check_fall_off()

	if not grounded:
		_update_air(delta)


func _advance_grounded(delta: float) -> void:
	var p := global_position
	p.x += (move_dir * move_speed) * delta
	p.z = plane_z

	global_position = p
	velocity = Vector3(move_dir * move_speed, velocity.y, 0.0)


func drive_root(target: Vector3, delta: float) -> void:
	if not grounded:
		return

	var old_y := global_position.y
	var ny := lerpf(old_y, target.y, 1.0 - exp(-follow_y * delta))

	global_position = Vector3(global_position.x, ny, plane_z)
	velocity.y = (ny - old_y) / maxf(delta, 0.0001)


func _ramp_intent(want_dir: int, target: float, blocked: bool, delta: float) -> void:
	var rate := decel_ground if grounded else accel_air

	if want_dir != 0:
		var wd := float(want_dir)

		if grounded and move_dir != 0.0 and wd != move_dir and move_speed > 0.05:
			target = 0.0
			rate = turn_brake
		else:
			move_dir = wd
			if grounded:
				rate = accel_ground if target > move_speed else decel_ground
			else:
				rate = accel_air

	if blocked:
		rate = maxf(rate, blocked_brake)

	move_speed = move_toward(move_speed, target, rate * delta)


func _update_stairs(dir: int, delta: float) -> void:
	var target := 0.0

	if grounded and dir != 0:
		var step := Vector3.RIGHT * float(dir) * stairs_probe
		var from := global_position + Vector3.UP * 1.0

		var here := _ray(from, from + Vector3.DOWN * 2.0)
		var ahead := _ray(from + step, from + step + Vector3.DOWN * 2.0)

		if not here.is_empty() and not ahead.is_empty():
			var rise := absf((ahead.position as Vector3).y - (here.position as Vector3).y)
			target = 1.0 if rise / maxf(stairs_probe, 0.05) > stairs_slope else 0.0

	_stairs_amt = move_toward(_stairs_amt, target, 4.0 * delta)


func _check_fall_off() -> void:
	var p := global_position
	var hit := _ray(p + Vector3.UP * 1.0, p + Vector3.DOWN * fall_off_height)

	if hit.is_empty():
		grounded = false
		_vy = minf(velocity.y, 0.0)


func _update_air(delta: float) -> void:
	var g := gravity * (fall_gravity_mult if _vy < 0.0 else 1.0)
	_vy -= g * delta

	var old := global_position
	var p := old

	if _is_blocked(int(move_dir)) and move_dir != 0.0:
		move_speed = move_toward(move_speed, 0.0, blocked_brake * delta)

	p.x += (move_dir * move_speed + push) * delta
	p.y += _vy * delta
	p.z = plane_z

	if _vy <= 0.0:
		var hit := _ray(Vector3(p.x, old.y + 0.4, p.z), Vector3(p.x, p.y - 0.02, p.z))
		if not hit.is_empty():
			p.y = (hit.position as Vector3).y
			_vy = 0.0
			grounded = true

	global_position = p
	velocity = Vector3(move_dir * move_speed + push, _vy, 0.0)


func _is_blocked(dir: int) -> bool:
	if dir == 0:
		return false

	var o := global_position
	var d := Vector3.RIGHT * float(dir) * wall_check_distance

	var heights: Array[float] = [max_step_up + 0.1, head_check_height]
	for h in heights:
		var from: Vector3 = o + Vector3.UP * h
		if not _ray(from, from + d).is_empty():
			return true

	return false


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, ground_mask)

	return space.intersect_ray(query)


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
		aim_pitch = atan2(to_aim.y, maxf(absf(to_aim.x), 0.001))

	return true
