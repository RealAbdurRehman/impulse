class_name CharacterMovement
extends Node3D

const DOOR_REACH := 1.8
const GROUP := &"characters"

signal jumped

@export var input: ActorInput
@export var health: Health
@export var blocker: StaticBody3D

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
@export_flags_3d_physics var character_mask: int = 8

@export var max_step_up := 0.6
@export var wall_check_distance := 0.45
@export var head_check_height := 1.5
@export var stand_height := 1.8
@export var head_clearance := 1.74
@export var crouch_height := 1.35
@export var crouch_head_check := 1.3

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
@export var face_aim := true

@export var flip_speed := 4.5
@export var air_flip_scale := 1.0

@export var aim_deadzone := 0.35
@export var aim_origin_height := 1.35

@export_group("Push")
@export var push_decay := 1.5

@export var shove_time := 0.3

var desired_speed := 0.0
var desired_dir := 0.0

var move_speed := 0.0
var move_dir := 0.0

var facing := 1
var moving_backward := false
var crouching := false

var grounded := true
var velocity := Vector3.ZERO

var plane_z := 0.0
var _door: Door
var _door_at := Vector3.ZERO

var push := 0.0

var focus: Node3D

var aim_point := Vector3.ZERO
var aim_pitch := 0.0

var aim_amount := 0.0
var aim_speed_scale := 1.0
var aim_zoom := 1.0
var aim_look := 1.0

var _stairs_amt := 0.0
var _target_yaw := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _vy := 0.0
var _own: Array[RID] = []
var _shove_dir := 0
var _shove_left := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	plane_z = global_position.z
	facing = 1 if sin(rotation.y) >= 0.0 else -1
	_target_yaw = PI * 0.5 * float(facing)
	rotation.y = _target_yaw
	_own = [blocker.get_rid()]


func is_friend(other: CharacterMovement) -> bool:
	return health.team != &"" and health.team == other.health.team


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

	if input.jump_pressed:
		_jump_buffer = jump_buffer_time
	else:
		_jump_buffer = maxf(0.0, _jump_buffer - delta)

	var dir := input.move

	_shove_left = maxf(_shove_left - delta, 0.0)

	var pushed := absf(dir) < 0.1 and (absf(push) > 0.1 or _shove_left > 0.0)
	if pushed:
		dir = float(_shove_dir) if _shove_left > 0.0 else clampf(push, -1.0, 1.0)

		if grounded and _edge_ahead(int(signf(dir))):
			push = 0.0
			_shove_left = 0.0
			pushed = false
			dir = 0.0

	crouching = grounded and (input.crouch or _ceiling_low(int(signf(dir))))

	var aimed := face_aim and input.has_aim
	if aimed:
		_update_aim()

	if not aimed and not pushed and absf(dir) > 0.1:
		facing = 1 if dir > 0.0 else -1

	moving_backward = absf(dir) > 0.1 and int(signf(dir)) != facing

	var speed := walk_speed
	if crouching:
		speed = crouch_speed
	elif moving_backward:
		speed = walk_speed * backpedal_speed_mult
	elif input.sprint and aim_amount < 0.1:
		speed = run_speed

	speed *= aim_speed_scale

	var want_dir := int(signf(dir)) if absf(dir) > 0.1 else 0
	var blocked := want_dir != 0 and _world_blocked(want_dir)
	if want_dir != 0 and _door != null:
		_door.shove(_door_at, Vector3.RIGHT * float(want_dir) * maxf(speed, walk_speed))

	if want_dir != 0 and not blocked:
		var ahead := _character_ahead(want_dir)
		if ahead != null:
			if ahead.gives_way(want_dir):
				speed = minf(speed, walk_speed * backpedal_speed_mult)
				ahead.shove(want_dir)
			else:
				blocked = true

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

		jumped.emit()

	if jump_cut < 1.0 and input.jump_released and not grounded and _vy > 0.0:
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

	p.x += (move_dir * move_speed) * delta
	p.y += _vy * delta
	p.z = plane_z

	if _vy <= 0.0:
		var hit := _ray(Vector3(p.x, old.y + 0.4, p.z), Vector3(p.x, p.y - 0.02, p.z))
		if not hit.is_empty():
			p.y = (hit.position as Vector3).y
			_vy = 0.0
			grounded = true
	else:
		var bump := _ray(Vector3(p.x, old.y + head_clearance - 0.1, p.z), Vector3(p.x, p.y + head_clearance + 0.02, p.z))
		if not bump.is_empty():
			p.y = maxf((bump.position as Vector3).y - head_clearance - 0.02, old.y)
			_vy = 0.0

	global_position = p
	velocity = Vector3(move_dir * move_speed, _vy, 0.0)


func shove(dir: int) -> void:
	_shove_dir = dir
	_shove_left = shove_time


func gives_way(dir: int, depth := 0) -> bool:
	if int(signf(input.move)) == -dir and absf(input.move) > 0.1:
		return false

	if _world_blocked(dir) or _edge_ahead(dir):
		return false

	var next := _character_ahead(dir)
	return next == null or (depth < 3 and next.gives_way(dir, depth + 1))


func _edge_ahead(dir: int) -> bool:
	var at := global_position + Vector3.RIGHT * float(dir) * 0.35
	return _ray(at + Vector3.UP * 0.5, at + Vector3.DOWN * 0.7).is_empty()


func _is_blocked(dir: int) -> bool:
	return dir != 0 and (_world_blocked(dir) or _character_ahead(dir) != null)


func _ceiling_low(dir: int) -> bool:
	var feet := global_position
	var reach := Vector3.UP * (stand_height - max_step_up + 0.05)
	for x in [0.0, float(dir) * (wall_check_distance + 0.1)]:
		var from := Vector3(feet.x + x, feet.y + max_step_up, plane_z)
		if not _ray(from, from + reach).is_empty():
			return true

	return false


func _head_height() -> float:
	return crouch_head_check if crouching else head_check_height


func _world_blocked(dir: int) -> bool:
	_door = null
	if dir == 0:
		return false

	var o := global_position
	var d := Vector3.RIGHT * float(dir) * wall_check_distance

	var heights: Array[float] = [max_step_up + 0.1, _head_height()]
	for h in heights:
		var from: Vector3 = o + Vector3.UP * h
		var hit := _ray(from, from + d * DOOR_REACH)
		if hit.is_empty():
			continue

		var panel := hit.collider as DoorPanel
		var near := absf(hit.position.x - o.x) <= wall_check_distance
		if panel == null:
			if near:
				return true

			continue

		if near and panel.door.resists(hit.position, Vector3.RIGHT * float(dir)):
			return true

		_door = panel.door
		_door_at = hit.position

	return false


func _character_ahead(dir: int) -> CharacterMovement:
	var o := global_position
	var d := Vector3.RIGHT * float(dir) * wall_check_distance

	var heights: Array[float] = [max_step_up + 0.1, _head_height()]
	for h in heights:
		var from: Vector3 = o + Vector3.UP * h
		var hit := _ray(from, from + d, character_mask, _own)
		if not hit.is_empty():
			var other := (hit.collider as Node).get_parent() as CharacterMovement
			if not is_friend(other):
				return other

	return null


func _ray(from: Vector3, to: Vector3, mask := ground_mask, exclude: Array[RID] = []) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)

	return space.intersect_ray(query)


func _update_aim() -> void:
	aim_point = input.aim_point

	var dx := aim_point.x - global_position.x
	if absf(dx) > aim_deadzone:
		facing = 1 if dx > 0.0 else -1

	var shoulder := global_position + Vector3.UP * aim_origin_height
	var to_aim := aim_point - shoulder
	if to_aim.length_squared() > 0.0001:
		aim_pitch = atan2(to_aim.y, maxf(absf(to_aim.x), 0.001))
