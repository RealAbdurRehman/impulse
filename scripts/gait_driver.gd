class_name GaitDriver
extends Node


class Foot:
	var target: Node3D
	var pole: Node3D
	var side: float = 1.0

	var planted := Vector3.ZERO
	var planted_normal := Vector3.UP
	var current := Vector3.ZERO
	var current_normal := Vector3.UP

	var start := Vector3.ZERO
	var start_normal := Vector3.UP
	var end := Vector3.ZERO
	var end_normal := Vector3.UP

	var swinging := false
	var recovery := false
	var t := 0.0
	var duration := 0.2


const NO_GROUND := -1.0e20

@export var player: Node3D

@export var left_foot_target: Node3D
@export var right_foot_target: Node3D

@export var left_knee_pole: Node3D
@export var right_knee_pole: Node3D

@export_flags_3d_physics var ground_mask: int = 1

@export_group("Stance")
@export var character_forward_local := Vector3(0, 0, 1)
@export var foot_lateral := 0.12
@export var ankle_height := 0.09
@export var foot_settle_speed := 30.0
@export var foot_turn_speed := 18.0
@export var normal_settle_speed := 8.0
## Maximum hip-to-ankle distance. Steps are capped to this so the IK is
## never asked for a target the leg physically cannot reach.
@export var max_leg_length := 0.85
## Fraction of max_leg_length at which a recovery step is forced.
@export_range(0.5, 1.0) var max_leg_stretch := 0.92

@export_group("Ground Conform")
@export_range(0.0, 1.0) var ground_align := 1.0
@export_range(0.0, 0.95) var swing_align_start := 0.55

@export_group("Balance")
@export var com_prediction_time := 0.22
@export var min_stability_margin := 0.06
@export var min_lean_to_step_deg := 4.0

@export_group("Stepping")
@export var base_step_distance := 0.26
@export var max_step_distance := 0.42
@export var step_cooldown := 0.12

@export var stance_time_walk := 0.55
@export var stance_time_run := 0.34
@export var swing_time_walk := 0.28
@export var swing_time_run := 0.22
@export_range(0.35, 0.8) var plant_bias := 0.58
@export var min_reach := 0.10
@export var max_stride := 0.70

@export var step_height := 0.10
@export var crouch_step_height := 0.055
@export var run_step_height_scale := 1.4

@export_group("Idle")
@export var idle_speed_threshold := 0.18
@export var idle_settle_dist := 0.06
@export var idle_settle_time := 0.22
@export var idle_settle_height := 0.04

@export_group("Body")
@export var crouch_drop := 0.32
@export var crouch_speed := 4.0
@export var run_speed := 3.2

@export var step_impact := 0.55
@export var step_impact_per_speed := 0.12
@export var max_step_impact := 1.3

@export var lean_max_degrees := 14.0
@export var lean_speed := 9.0

@export var hips_spring := 200.0
@export var hips_damping := 30.0
@export var landing_dip := 0.20
@export var max_landing_impulse := 1.8
@export var hips_min_offset := -0.28
@export var hips_max_offset := 0.12

@export_group("Air pose")
@export var air_foot_height_up := 0.10
@export var air_foot_height_down := 0.02
@export var air_foot_spread := 0.10
@export var air_follow_speed := 18.0

var lean_angle := 0.0
var hips_offset_y := 0.0
var lean_axis := Vector3.RIGHT

var _feet: Array[Foot] = []
var _hips_vel := 0.0
var _crouch_amt := 0.0
var _prev_vy := 0.0
var _was_on_floor := true
var _swing_idx := -1
var _swing_cooldown := 0.0


func _ready() -> void:
	if player == null:
		push_warning("GaitDriver: no player assigned")
		return

	if "run_speed" in player:
		run_speed = player.run_speed

	_feet.append(_make_foot(left_foot_target, left_knee_pole, 1.0))
	_feet.append(_make_foot(right_foot_target, right_knee_pole, -1.0))

	var pb := _player_basis()
	var fwd: Vector3 = (pb * character_forward_local).normalized()
	var side_vec: Vector3 = pb.x.normalized()

	for f in _feet:
		var b := _basis_from_normal(f.current_normal, fwd)
		f.target.global_transform = Transform3D(b, f.current)
		if f.pole:
			f.pole.global_position = _player_pos() \
					+ Vector3.UP * 0.5 \
					+ fwd * 0.8 \
					+ side_vec * foot_lateral * f.side


func _make_foot(target: Node3D, pole: Node3D, side: float) -> Foot:
	var f := Foot.new()

	f.target = target
	f.pole = pole
	f.side = side

	target.top_level = true
	if pole:
		pole.top_level = true

	var base := _player_pos() + _player_basis().x.normalized() * foot_lateral * side
	var g := _sample_ground(base)
	var y: float = g[1] if g[0] else _player_pos().y
	var n: Vector3 = g[2] if g[0] else Vector3.UP

	f.planted = Vector3(base.x, y + ankle_height, base.z)
	f.planted_normal = n
	f.current = f.planted
	f.current_normal = n

	return f


func _physics_process(delta: float) -> void:
	if player == null:
		return

	var vel: Vector3 = player.velocity
	var flat := Vector3(vel.x, 0.0, vel.z)
	var speed := flat.length()
	var on_floor: bool = player.is_on_floor()

	var desired_speed := _get_desired_speed()
	var crouching := on_floor and Input.is_action_pressed("crouch")

	var pb := _player_basis()
	var fwd: Vector3 = (pb * character_forward_local).normalized()
	var side_vec: Vector3 = pb.x.normalized()

	_crouch_amt = move_toward(_crouch_amt, 1.0 if crouching else 0.0, crouch_speed * delta)
	_swing_cooldown = maxf(0.0, _swing_cooldown - delta)

	if on_floor and not _was_on_floor:
		_hips_vel -= clampf(-_prev_vy * landing_dip, 0.0, max_landing_impulse)
		for f in _feet:
			_land_foot(f)

	var lean_target := 0.0
	if on_floor:
		var desired_ratio := clampf(desired_speed / maxf(run_speed, 0.01), 0.0, 1.0)
		var actual_ratio := clampf(speed / maxf(run_speed, 0.01), 0.0, 1.0)
		var ratio := maxf(desired_ratio, actual_ratio)
		lean_target = deg_to_rad(lean_max_degrees) * ratio

	lean_angle = lerpf(lean_angle, lean_target, 1.0 - exp(-lean_speed * delta))
	if flat.length_squared() > 0.01:
		lean_axis = Vector3.UP.cross(flat.normalized()).normalized()
	elif pb.z.length_squared() > 0.01:
		var f2 := (pb * character_forward_local)
		f2.y = 0.0
		if f2.length_squared() > 0.01:
			lean_axis = Vector3.UP.cross(f2.normalized()).normalized()

	var lean_ok := lean_angle >= deg_to_rad(min_lean_to_step_deg)

	var step_idx := -1
	if on_floor and _swing_cooldown <= 0.0:
		step_idx = _choose_step_foot(side_vec, fwd, flat, speed, desired_speed, lean_ok, crouching)

	for i in _feet.size():
		var f := _feet[i]

		if on_floor:
			if i == step_idx and not f.swinging and _swing_idx == -1:
				_execute_step(f, i, side_vec, fwd, flat, speed, desired_speed)
			_update_grounded_foot(f, side_vec, fwd, delta)
		else:
			_update_air_foot(f, side_vec, fwd, vel.y, delta)

		_apply_foot(f, side_vec, fwd, delta)

	var target_h := -crouch_drop * _crouch_amt
	_hips_vel += ((target_h - hips_offset_y) * hips_spring - _hips_vel * hips_damping) * delta
	hips_offset_y += _hips_vel * delta
	hips_offset_y = clampf(hips_offset_y, target_h + hips_min_offset, target_h + hips_max_offset)
	_hips_vel = clampf(_hips_vel, -4.0, 4.0)

	_was_on_floor = on_floor
	_prev_vy = vel.y


func _choose_step_foot(
	side_vec: Vector3,
	fwd: Vector3,
	flat: Vector3,
	speed: float,
	desired_speed: float,
	lean_ok: bool,
	crouching: bool,
) -> int:
	if _swing_idx != -1:
		return -1

	var com := _player_pos()
	var stretch_limit := max_leg_length * max_leg_stretch

	# Reach safety net: fires before any other logic and regardless of lean,
	# crouch, or motion state. Prevents the leg from ever being asked for a
	# target outside its physical range.
	if (_feet[0].planted - com).length() > stretch_limit:
		return 0
	if (_feet[1].planted - com).length() > stretch_limit:
		return 1

	var moving := speed > idle_speed_threshold or desired_speed > idle_speed_threshold

	if not moving:
		var base_l := com + side_vec * foot_lateral * _feet[0].side
		var base_r := com + side_vec * foot_lateral * _feet[1].side
		var dl := Vector2(_feet[0].planted.x - base_l.x, _feet[0].planted.z - base_l.z).length()
		var dr := Vector2(_feet[1].planted.x - base_r.x, _feet[1].planted.z - base_r.z).length()

		if dl > idle_settle_dist and dl >= dr:
			return 0
		if dr > idle_settle_dist:
			return 1
		return -1

	# Crouch bypasses the lean gate so crouch-walking actually steps.
	var lean_gate := lean_ok or crouching
	if not lean_gate:
		return -1

	var com_vel: Vector3 = (
		player.com_velocity()
		if player.has_method("com_velocity")
		else Vector3(flat.x, 0.0, flat.z)
	)
	var predicted := com + Vector3(com_vel.x, 0.0, com_vel.z) * com_prediction_time

	var left := _feet[0].planted
	var right := _feet[1].planted
	var support_center := (left + right) * 0.5

	var lateral_axis := side_vec
	var support_radius := absf((left - right).dot(lateral_axis)) * 0.5
	var lateral_pred := (predicted - support_center).dot(lateral_axis)
	var lateral_margin := support_radius - absf(lateral_pred)

	var move_dir := flat.normalized() if speed > 0.05 else fwd
	move_dir.y = 0.0
	if move_dir.length_squared() < 0.0001:
		move_dir = fwd

	var traill := -(left - predicted).dot(move_dir)
	var trailr := -(right - predicted).dot(move_dir)

	var sp := clampf(speed / maxf(run_speed, 0.01), 0.0, 1.0)
	var stance := lerpf(stance_time_walk, stance_time_run, sp)
	var stride := minf(speed * stance, max_stride)
	var trail_threshold := maxf(stride * (1.0 - plant_bias), min_reach)

	var lateral_trigger := lateral_margin < min_stability_margin
	var forward_trigger := traill > trail_threshold or trailr > trail_threshold

	if not (lateral_trigger or forward_trigger):
		return -1

	if traill >= trailr:
		return 0
	return 1


func _execute_step(
	f: Foot,
	idx: int,
	side_vec: Vector3,
	fwd: Vector3,
	flat: Vector3,
	speed: float,
	desired_speed: float,
) -> void:
	var com := _player_pos()
	var moving := speed > idle_speed_threshold or desired_speed > idle_speed_threshold
	var reach_limited := (f.planted - com).length() > max_leg_length * max_leg_stretch

	var end := Vector3.ZERO
	var end_normal := Vector3.UP
	var duration := idle_settle_time
	var is_recovery := false

	if not moving or reach_limited:
		var base := com + side_vec * foot_lateral * f.side
		var g := _sample_ground(Vector3(base.x, 0.0, base.z))
		var y: float = g[1] if g[0] else _player_pos().y
		end_normal = g[2] if g[0] else Vector3.UP
		end = Vector3(base.x, y + ankle_height, base.z)
		duration = idle_settle_time
		is_recovery = true
	else:
		var com_vel: Vector3 = (
			player.com_velocity()
			if player.has_method("com_velocity")
			else Vector3(flat.x, 0.0, flat.z)
		)
		var predicted := com + Vector3(com_vel.x, 0.0, com_vel.z) * com_prediction_time

		var move_dir := flat.normalized() if speed > 0.05 else fwd
		move_dir.y = 0.0
		if move_dir.length_squared() < 0.0001:
			move_dir = fwd

		var sp := clampf(speed / maxf(run_speed, 0.01), 0.0, 1.0)
		var swing_t := lerpf(swing_time_walk, swing_time_run, sp)

		var lateral_offset := side_vec * foot_lateral * f.side
		var target := Vector3(com.x, 0.0, com.z) + lateral_offset \
				+ move_dir * base_step_distance \
				+ Vector3(predicted.x - com.x, 0.0, predicted.z - com.z) * 0.6

		var to_target := target - com
		to_target.y = 0.0
		if to_target.length() > max_step_distance:
			to_target = to_target.normalized() * max_step_distance
			target = Vector3(com.x + to_target.x, 0.0, com.z + to_target.z)

		var g := _sample_ground(Vector3(target.x, 0.0, target.z))
		if g[0]:
			target.y = g[1] + ankle_height
			end_normal = g[2]
		else:
			target.y = _player_pos().y + ankle_height
			end_normal = Vector3.UP

		end = _clamp_horizontal_reach(target, com)
		duration = swing_t

	f.duration = duration
	f.start = f.planted
	f.start_normal = f.planted_normal
	f.end = end
	f.end_normal = end_normal
	f.t = 0.0
	f.swinging = true
	f.recovery = is_recovery
	_swing_idx = idx
	_swing_cooldown = step_cooldown


func _clamp_horizontal_reach(target: Vector3, hips: Vector3) -> Vector3:
	var vert := target.y - hips.y
	var max_horiz_sq := max_leg_length * max_leg_length - vert * vert
	if max_horiz_sq <= 0.0:
		return target

	var max_horiz := sqrt(max_horiz_sq)
	var horiz := Vector3(target.x - hips.x, 0.0, target.z - hips.z)
	var horiz_len := horiz.length()
	if horiz_len > max_horiz:
		horiz = horiz * (max_horiz / horiz_len)
		target.x = hips.x + horiz.x
		target.z = hips.z + horiz.z
	return target


func _update_grounded_foot(f: Foot, side_vec: Vector3, fwd: Vector3, delta: float) -> void:
	if f.swinging:
		f.t += delta / maxf(f.duration, 0.001)

		var k := clampf(f.t, 0.0, 1.0)
		var pos := f.start.lerp(f.end, smoothstep(0.0, 1.0, k))

		var lift := step_height
		if f.recovery:
			lift = idle_settle_height
		else:
			var spd := Vector3(player.velocity.x, 0.0, player.velocity.z).length()
			var sp_ratio := clampf(spd / maxf(run_speed, 0.01), 0.0, 1.0)
			lift *= lerpf(1.0, run_step_height_scale, sp_ratio)
		lift = lerpf(lift, crouch_step_height, _crouch_amt)

		pos.y += sin(pow(k, 0.75) * PI) * lift
		f.current = pos

		var na := swing_align_start
		if k > na:
			var nb := smoothstep(0.0, 1.0, (k - na) / (1.0 - na))
			f.current_normal = f.start_normal.slerp(f.end_normal, nb).normalized()
		else:
			f.current_normal = f.start_normal

		if f.t >= 1.0:
			f.swinging = false
			f.recovery = false
			f.planted = f.end
			f.planted_normal = f.end_normal
			f.current = f.end
			f.current_normal = f.end_normal
			_on_foot_plant(f)
			_swing_idx = -1
		return

	var g := _sample_ground(f.planted)
	if g[0]:
		f.planted.y = g[1] + ankle_height
		var n: Vector3 = g[2]
		var t := 1.0 - exp(-normal_settle_speed * delta)
		f.planted_normal = f.planted_normal.slerp(n, t).normalized()

	f.current = f.current.lerp(f.planted, 1.0 - exp(-foot_settle_speed * delta))
	f.current_normal = f.current_normal.slerp(f.planted_normal, 1.0 - exp(-foot_turn_speed * delta)).normalized()


func _update_air_foot(f: Foot, side_vec: Vector3, fwd: Vector3, vy: float, delta: float) -> void:
	f.swinging = false
	f.recovery = false
	_swing_idx = -1

	var up_h := air_foot_height_up if vy > 0.0 else air_foot_height_down
	var pos := _player_pos() \
			+ side_vec * foot_lateral * f.side \
			+ fwd * (air_foot_spread * f.side) \
			+ Vector3.UP * (up_h + ankle_height)

	f.planted = f.planted.lerp(pos, 1.0 - exp(-air_follow_speed * delta))
	f.current = f.planted

	var body_up: Vector3 = _player_basis().y.normalized()
	if body_up.length_squared() < 0.0001:
		body_up = Vector3.UP
	var blend := 1.0 - exp(-air_follow_speed * 0.5 * delta)
	f.current_normal = f.current_normal.slerp(body_up, blend).normalized()
	f.planted_normal = f.current_normal


func _land_foot(f: Foot) -> void:
	f.swinging = false
	f.recovery = false
	var g := _sample_ground(f.current)
	if g[0]:
		f.planted = Vector3(f.current.x, g[1] + ankle_height, f.current.z)
		f.planted_normal = g[2]
	else:
		f.planted = Vector3(f.current.x, _player_pos().y + ankle_height, f.current.z)
		f.planted_normal = Vector3.UP
	f.current = f.planted
	f.current_normal = f.planted_normal
	_swing_idx = -1


func _on_foot_plant(f: Foot) -> void:
	var speed := Vector3(player.velocity.x, 0.0, player.velocity.z).length()
	_hips_vel -= clampf(step_impact + speed * step_impact_per_speed, 0.0, max_step_impact)


func _apply_foot(f: Foot, side_vec: Vector3, fwd: Vector3, delta: float) -> void:
	var want := _basis_from_normal(f.current_normal, fwd)
	var cur := f.target.global_basis.orthonormalized()
	var new_basis := cur.slerp(want, 1.0 - exp(-foot_turn_speed * delta))

	f.target.global_transform = Transform3D(new_basis.orthonormalized(), f.current)

	if f.pole:
		f.pole.global_position = _player_pos() \
				+ Vector3.UP * (0.5 + hips_offset_y * 0.5) \
				+ fwd * 0.8 \
				+ side_vec * foot_lateral * f.side


func _basis_from_normal(normal: Vector3, fwd: Vector3) -> Basis:
	var n := normal
	if n.length_squared() < 0.0001:
		n = Vector3.UP
	n = n.normalized()

	var f := fwd - n * fwd.dot(n)
	if f.length_squared() < 0.0001:
		f = Vector3.FORWARD - n * Vector3.FORWARD.dot(n)
	if f.length_squared() < 0.0001:
		f = Vector3.RIGHT - n * Vector3.RIGHT.dot(n)
	f = f.normalized()

	var z_axis := -f
	var x_axis := n.cross(z_axis).normalized()

	return Basis(x_axis, n, z_axis).orthonormalized()


func _player_pos() -> Vector3:
	if player.has_method("body_position"):
		return player.body_position()
	return player.global_position


func _player_basis() -> Basis:
	if player.has_method("body_basis"):
		return player.body_basis()
	return player.global_basis


func _get_desired_speed() -> float:
	if "desired_speed" in player:
		return player.desired_speed
	return 0.0


func _sample_ground(p: Vector3) -> Array:
	var space := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		p + Vector3.UP * 0.6,
		p + Vector3.DOWN * 1.5,
		ground_mask,
	)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return [false, NO_GROUND, Vector3.UP]
	var n: Vector3 = hit.normal
	if n.length_squared() < 0.0001:
		n = Vector3.UP
	return [true, hit.position.y, n.normalized()]
