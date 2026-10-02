class_name GaitDriver
extends Node


class Foot:
	var pole: Node3D
	var target: Node3D

	var side := 1.0

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
@export var foot_lateral := 0.12
@export var ankle_height := 0.09

@export var foot_settle_speed := 30.0
@export var character_forward_local := Vector3(0, 0, 1)

@export var foot_turn_speed := 30.0
@export var normal_settle_speed := 24.0

@export var auto_leg_length := true
@export var max_leg_length := 0.85

@export_range(0.5, 1.0) var max_leg_stretch := 0.97

@export_group("Ground Conform")
@export_range(0.0, 1.0) var ground_align := 1.0
@export_range(0.0, 0.95) var swing_align_start := 0.55

@export_group("Balance")
@export var com_prediction_time := 0.22
@export var min_stability_margin := 0.06
@export var min_lean_to_step_deg := 4.0

@export_group("Stepping")
@export var retarget_speed := 20.0

@export var step_interval_walk := 0.55
@export var step_interval_run := 0.42

@export var max_step_distance := 0.30
@export var max_step_distance_run := 0.40
@export var step_cooldown := 0.10

@export var leg_back_shift := 0.07
@export var leg_back_shift_run := 0.12

@export var swing_time_walk := 0.36
@export var swing_time_run := 0.24

@export var step_height := 0.1
@export var crouch_step_height := 0.1
@export var run_step_height_scale := 1.6

@export_range(0.0, 1.0) var landing_lead_comp := 1.0

@export_group("Idle")
@export var idle_settle_dist := 0.06
@export var idle_settle_time := 0.22
@export var idle_settle_height := 0.04
@export var idle_speed_threshold := 0.18

@export_group("Body")
@export var move_drop := 0.04
@export var run_drop := 0.06
@export var crouch_drop := 0.32

@export var crouch_lean_degrees := 12.0
@export var crouch_foot_stagger := 0.16
@export var crouch_foot_lateral_extra := 0.08

@export var run_speed := 3.2
@export var crouch_speed := 4.0

@export var step_impact := 0.85
@export var max_step_impact := 1.8
@export var step_impact_per_speed := 0.15

@export var hips_spring := 200.0
@export var hips_damping := 30.0
@export var hips_min_offset := -0.45
@export var hips_max_offset := 0.12

@export var lean_speed := 9.0
@export var lean_max_degrees := 14.0

@export_range(0.3, 1.0) var crouch_step_scale := 0.6
@export_range(0.0, 1.0) var crouch_impact_scale := 0.15

@export_group("Air pose")
@export var air_bend_time := 0.28
@export var air_extend_time := 0.12
@export var air_extend_lead := 0.36

@export var air_foot_spread := 0.12
@export var air_follow_speed := 12.0

@export var air_tuck_in_time := 0.14
@export var air_tuck_out_time := 0.14

@export var air_leg_asymmetry := 0.10
@export var air_follow_rise_speed := 14.0

@export_range(0.3, 0.85) var air_hang_rising := 0.55
@export_range(0.3, 0.85) var air_hang_falling := 0.72

@export_range(0.0, 1.5) var air_stride_lead := 0.9
@export_range(0.0, 1.0) var air_tuck_strength := 1.0
@export_range(0.0, 1.0) var air_land_straightness := 0.0

@export_group("Landing")
@export var landing_drop := 0.30

@export var landing_dip_speed := 2.0
@export var landing_ref_speed := 6.0

@export var landing_recover_time := 0.45

var lean_angle := 0.0
var hips_offset_y := 0.0

var lean_axis := Vector3.RIGHT

var air_tuck := 0.0
var air_half_angle := 0.8
var air_fwd := Vector3.FORWARD

var landing_amount := 0.0

var _feet: Array[Foot] = []

var _hips_vel := 0.0

var _run_amt := 0.0
var _move_amt := 0.0
var _crouch_amt := 0.0
var _land_amt := 0.0

var _since_step := 0.0

var _hip_h := -1.0

var _leg_len := -1.0
var _leg_len_tried := false

var _air_time := 0.0

var _hang_s := 0.97
var _air_ext := 0.0

var _tuck_t := 0.0
var _floor_ticks := 0

var _prev_vy := 0.0
var _was_on_floor := true

var _swing_idx := -1
var _swing_cooldown := 0.0


func _ready() -> void:
	if player == null:
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
	if player == null or _feet.size() < 2:
		return

	var vel: Vector3 = player.velocity
	var flat := Vector3(vel.x, 0.0, vel.z)
	var speed := flat.length()

	var raw_floor: bool = player.is_on_floor()
	_floor_ticks = _floor_ticks + 1 if raw_floor else 0

	var on_floor: bool = raw_floor and (_was_on_floor or _floor_ticks >= 2)

	var desired_speed := _get_desired_speed()
	var crouching := on_floor and Input.is_action_pressed("crouch")

	var pb := _player_basis()
	var fwd: Vector3 = (pb * character_forward_local).normalized()
	var side_vec: Vector3 = pb.x.normalized()

	_crouch_amt = move_toward(_crouch_amt, 1.0 if crouching else 0.0, crouch_speed * delta)
	_swing_cooldown = maxf(0.0, _swing_cooldown - delta)
	_since_step += delta

	if not _leg_len_tried and auto_leg_length and player.has_method("measure_leg_length"):
		_leg_len_tried = true

		var measured: float = player.measure_leg_length()
		if measured > 0.2:
			_leg_len = measured

	if not on_floor:
		_air_time += delta
	else:
		_air_time = 0.0

	var root_y := (_leg_root(0).y + _leg_root(1).y) * 0.5
	var ik_h := root_y - minf(_feet[0].planted.y, _feet[1].planted.y)

	if _hip_h < 0.0:
		_hip_h = ik_h
	elif on_floor:
		_hip_h = lerpf(_hip_h, ik_h, 1.0 - exp(-4.0 * delta))

	if on_floor and not _was_on_floor:
		var impact := clampf(-_prev_vy / maxf(landing_ref_speed, 0.01), 0.0, 1.0)
		_land_amt = maxf(_land_amt, impact)
		_hips_vel -= impact * landing_dip_speed

		for f in _feet:
			_land_foot(f)

	_land_amt = move_toward(_land_amt, 0.0, delta / maxf(landing_recover_time, 0.05))
	landing_amount = smoothstep(0.0, 1.0, _land_amt)

	var lean_target := 0.0
	if on_floor:
		var desired_ratio := clampf(desired_speed / maxf(run_speed, 0.01), 0.0, 1.0)
		var actual_ratio := clampf(speed / maxf(run_speed, 0.01), 0.0, 1.0)

		var ratio := maxf(desired_ratio, actual_ratio)
		lean_target = deg_to_rad(lean_max_degrees) * ratio

	lean_target += deg_to_rad(crouch_lean_degrees) * _crouch_amt

	var run_target := 0.0
	if on_floor and not crouching:
		run_target = smoothstep(0.5, 1.0, speed / maxf(run_speed, 0.01))

	_run_amt = lerpf(_run_amt, run_target, 1.0 - exp(-6.0 * delta))

	var move_target := 0.0
	if on_floor and not crouching:
		move_target = clampf(speed / maxf(run_speed * 0.5, 0.01), 0.0, 1.0)

	_move_amt = lerpf(_move_amt, move_target, 1.0 - exp(-6.0 * delta))
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
	if on_floor:
		step_idx = _choose_step_foot(side_vec, fwd, flat, speed, desired_speed, lean_ok, crouching)

	if not on_floor:
		if _was_on_floor:
			_hang_s = clampf(_current_straightness(), 0.5, 0.99)
			_air_ext = 0.0

		_update_air_state(vel.y, delta)

	for i in _feet.size():
		var f := _feet[i]

		if on_floor:
			if i == step_idx and not f.swinging:
				_execute_step(f, i, side_vec, fwd, speed, desired_speed)

			_update_grounded_foot(f, side_vec, fwd, delta)
		else:
			_update_air_foot(f, side_vec, fwd, vel.y, delta)

		_apply_foot(f, side_vec, fwd, delta)

	if not on_floor:
		_tuck_t = move_toward(_tuck_t, 1.0, delta / maxf(air_tuck_in_time, 0.02))
	else:
		_tuck_t = move_toward(_tuck_t, 0.0, delta / maxf(air_tuck_out_time, 0.02))

	air_tuck = smoothstep(0.0, 1.0, _tuck_t) * air_tuck_strength

	var fh := Vector3(fwd.x, 0.0, fwd.z)
	if fh.length_squared() > 0.0001:
		air_fwd = fh.normalized()

	var target_h := -crouch_drop * _crouch_amt \
			- run_drop * _run_amt \
			- move_drop * _move_amt \
			- landing_drop * landing_amount

	_hips_vel += ((target_h - hips_offset_y) * hips_spring - _hips_vel * hips_damping) * delta

	hips_offset_y += _hips_vel * delta
	hips_offset_y = clampf(hips_offset_y, target_h + hips_min_offset, target_h + hips_max_offset)

	_hips_vel = clampf(_hips_vel, -5.0, 5.0)

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
	var com := _player_pos()
	var stretch_limit := _l() * max_leg_stretch
	var moving := speed > idle_speed_threshold or desired_speed > idle_speed_threshold

	var move_dir := flat.normalized() if speed > 0.05 else fwd
	move_dir.y = 0.0

	if move_dir.length_squared() < 0.0001:
		move_dir = fwd

	var v_eff := _effective_speed(speed, desired_speed)

	var half := _stride_half(v_eff)
	var interval := _step_interval(v_eff)

	var ref := com - move_dir * _back_shift(v_eff)

	for i in 2:
		var fi := _feet[i]
		if fi.swinging:
			continue

		var rf := _leg_root(i)

		var stretched := (fi.planted - rf).length() > stretch_limit \
				and (moving or Vector2(fi.planted.x - rf.x, fi.planted.z - rf.z).length() > 0.2)

		var dragged := moving and (ref - fi.planted).dot(move_dir) > half * 1.5 + 0.06
		if stretched or dragged:
			return i

	if _swing_idx != -1 or _swing_cooldown > 0.0:
		return -1

	var ok0 := not _feet[0].swinging
	var ok1 := not _feet[1].swinging
	if not moving:
		var base_l := com + _stance_offset(_feet[0], side_vec, fwd)
		var base_r := com + _stance_offset(_feet[1], side_vec, fwd)

		var dl := Vector2(_feet[0].planted.x - base_l.x, _feet[0].planted.z - base_l.z).length() if ok0 else 0.0
		var dr := Vector2(_feet[1].planted.x - base_r.x, _feet[1].planted.z - base_r.z).length() if ok1 else 0.0

		if dl > idle_settle_dist and dl >= dr:
			return 0
		if dr > idle_settle_dist:
			return 1

		return -1

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

	var support_radius := absf((left - right).dot(side_vec)) * 0.5
	var lateral_pred := (predicted - support_center).dot(side_vec)
	var lateral_margin := support_radius - absf(lateral_pred)

	var traill := (ref - left).dot(move_dir) if ok0 else -INF
	var trailr := (ref - right).dot(move_dir) if ok1 else -INF
	var max_trail := maxf(traill, trailr)
	if max_trail == -INF:
		return -1

	var due := _since_step >= interval and max_trail > half * 0.35
	var geo := max_trail >= half * 1.05 and _since_step >= interval * 0.45
	var lateral_trigger := lateral_margin < min_stability_margin and _since_step >= interval * 0.5

	if not (due or geo or lateral_trigger):
		return -1

	if traill >= trailr:
		return 0

	return 1


func _execute_step(
	f: Foot,
	idx: int,
	side_vec: Vector3,
	fwd: Vector3,
	speed: float,
	desired_speed: float,
) -> void:
	var com := _player_pos()
	var moving := speed > idle_speed_threshold or desired_speed > idle_speed_threshold
	var reach_limited := (f.planted - _leg_root(idx)).length() > _l() * max_leg_stretch

	var end := Vector3.ZERO
	var end_normal := Vector3.UP
	var duration := idle_settle_time
	var is_recovery := false

	var sp_now := clampf(speed / maxf(run_speed, 0.01), 0.0, 1.0)
	var v_eff := _effective_speed(speed, desired_speed)

	if not moving:
		var base := com + _stance_offset(f, side_vec, fwd, true)
		var g := _sample_ground(Vector3(base.x, com.y, base.z))
		var y: float = g[1] if g[0] else _player_pos().y

		end_normal = g[2] if g[0] else Vector3.UP
		end = Vector3(base.x, y + ankle_height, base.z)

		duration = idle_settle_time
		is_recovery = true
	else:
		var swing_t := lerpf(swing_time_walk, swing_time_run, sp_now)
		if reach_limited:
			swing_t *= 0.7

		var landing := _moving_landing(f, side_vec, fwd, swing_t)
		end = landing[0]
		end_normal = landing[1]

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
	_since_step = 0.0
	_swing_cooldown = clampf(_step_interval(v_eff) - duration, 0.0, step_cooldown)


func _stance_offset(f: Foot, side_vec: Vector3, fwd: Vector3, with_stagger := true) -> Vector3:
	var lat := foot_lateral + crouch_foot_lateral_extra * _crouch_amt
	var o := side_vec * lat * f.side
	if with_stagger:
		o += fwd * crouch_foot_stagger * _crouch_amt * f.side

	return o


func _effective_speed(speed: float, desired_speed: float) -> float:
	return maxf(speed, desired_speed * 0.6)


func _speed_ratio(v: float) -> float:
	return clampf(v / maxf(run_speed, 0.01), 0.0, 1.0)


func _nominal_interval(v: float) -> float:
	return lerpf(step_interval_walk, step_interval_run, _speed_ratio(v))


func _stride_cap(v: float) -> float:
	var t := clampf((_speed_ratio(v) - 0.5) / 0.5, 0.0, 1.0)
	var cap := lerpf(max_step_distance, max_step_distance_run, t) \
			* lerpf(1.0, crouch_step_scale, _crouch_amt)

	if _hip_h > 0.0:
		var lim := _l() * 0.97
		var reach_h := sqrt(maxf(lim * lim - _hip_h * _hip_h, 0.0))
		cap = maxf(minf(cap, reach_h * 0.9), cap * 0.6)

	return cap


func _back_shift(v: float) -> float:
	var ratio := _speed_ratio(v)
	var ramp := clampf(ratio / 0.5, 0.0, 1.0)
	var t := clampf((ratio - 0.5) / 0.5, 0.0, 1.0)

	return lerpf(leg_back_shift, leg_back_shift_run, t) * ramp * lerpf(1.0, 0.3, _crouch_amt)


func _stride_half(v: float) -> float:
	return minf(v * _nominal_interval(v) * 0.5, _stride_cap(v))


func _step_interval(v: float) -> float:
	var interval := _nominal_interval(v)
	if v > 0.05:
		interval = minf(interval, 2.0 * _stride_half(v) / v)

	return maxf(interval, 0.2)


func _moving_landing(f: Foot, side_vec: Vector3, fwd: Vector3, swing_left: float) -> Array:
	var com := _player_pos()
	var flat := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var speed := flat.length()

	var move_dir := flat.normalized() if speed > 0.05 else fwd
	move_dir.y = 0.0

	if move_dir.length_squared() < 0.0001:
		move_dir = fwd

	var v_eff := _effective_speed(speed, _get_desired_speed())

	var com_td := Vector3(com.x, 0.0, com.z) + flat * swing_left * landing_lead_comp
	com_td -= move_dir * _back_shift(v_eff)

	var offset := _stance_offset(f, side_vec, fwd, false) + move_dir * _stride_half(v_eff)
	offset.y = 0.0

	var target := com_td + offset

	var normal := Vector3.UP

	var g := _sample_ground(Vector3(target.x, com.y, target.z))
	if g[0]:
		target.y = g[1] + ankle_height
		normal = g[2]
	else:
		target.y = _player_pos().y + ankle_height

	var root := _leg_root(maxi(_feet.find(f), 0))
	var hips_td := Vector3(
		root.x + flat.x * swing_left * landing_lead_comp,
		root.y,
		root.z + flat.z * swing_left * landing_lead_comp,
	)

	return [_clamp_horizontal_reach(target, hips_td), normal]


func _clamp_horizontal_reach(target: Vector3, hips: Vector3) -> Vector3:
	var vert := target.y - hips.y
	var reach := _l() * 0.95
	var max_horiz_sq := reach * reach - vert * vert

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
		if not f.recovery and k < 0.9:
			var left := (1.0 - k) * f.duration
			var landing := _moving_landing(f, side_vec, fwd, left)
			var rt := 1.0 - exp(-retarget_speed * delta)

			f.end = f.end.lerp(landing[0], rt)
			f.end_normal = f.end_normal.slerp(landing[1], rt).normalized()

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
			var was_recovery := f.recovery

			f.swinging = false
			f.recovery = false

			f.planted = f.end
			f.planted_normal = f.end_normal

			f.current = f.end
			f.current_normal = f.end_normal

			_on_foot_plant(f, was_recovery)

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


func _current_straightness() -> float:
	var sum := 0.0
	for i in 2:
		sum += (_feet[i].current - _leg_root(i)).length()

	return sum / (2.0 * maxf(_l(), 0.01))


func _update_air_state(vy: float, delta: float) -> void:
	var l := _l()
	var root_y := (_leg_root(0).y + _leg_root(1).y) * 0.5

	var floor_y := NO_GROUND
	for f in _feet:
		var g := _sample_ground(Vector3(f.current.x, root_y, f.current.z), 4.0)
		if g[0]:
			var n: Vector3 = g[2]

			if n.y > 0.6 and g[1] > floor_y:
				floor_y = g[1]

	var ext := 0.0
	var fall_speed := maxf(-vy, 0.0)
	if floor_y > NO_GROUND * 0.5 and fall_speed > 0.5:
		var slack := root_y - (floor_y + ankle_height) - l * air_land_straightness
		var time_to_impact := slack / maxf(fall_speed, 0.5)

		ext = (1.0 - smoothstep(0.14, air_extend_lead, time_to_impact)) \
				* smoothstep(0.5, 2.0, fall_speed)

	var fall_t := clampf(0.5 - vy / 4.0, 0.0, 1.0)
	var bent := lerpf(air_hang_rising, air_hang_falling, fall_t)
	var target := lerpf(bent, air_land_straightness, ext)

	var time := air_extend_time if target > _hang_s else air_bend_time
	_hang_s = lerpf(_hang_s, target, 1.0 - exp(-3.0 / maxf(time, 0.02) * delta))
	_air_ext = lerpf(_air_ext, ext, 1.0 - exp(-3.0 / maxf(air_extend_time, 0.02) * delta))

	air_half_angle = acos(clampf(_hang_s, 0.0, 1.0))


func _update_air_foot(f: Foot, side_vec: Vector3, fwd: Vector3, vy: float, delta: float) -> void:
	f.swinging = false
	f.recovery = false

	_swing_idx = -1

	var slot := maxi(_feet.find(f), 0)
	var hips := _ik_hips()
	var root := _leg_root(slot)

	var fall_t := clampf(0.5 - vy / 4.0, 0.0, 1.0)
	var hang := _l() * _hang_s

	var flat := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var spd := flat.length()
	var dir := flat.normalized() if spd > 0.3 else fwd

	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = fwd

	var lead := _stride_half(_effective_speed(spd, 0.0)) * air_stride_lead if spd > 0.3 else 0.0

	var xz := hips \
			+ side_vec * foot_lateral * f.side \
			+ dir * (air_foot_spread + lead) * f.side \
			- dir * _back_shift(_effective_speed(spd, 0.0))

	var y := root.y - hang + air_leg_asymmetry * f.side * (1.0 - fall_t) * (1.0 - _air_ext)

	var ground_n := Vector3.UP

	var g := _sample_ground(Vector3(xz.x, hips.y, xz.z))
	if g[0]:
		y = maxf(y, g[1] + ankle_height)

		var gn: Vector3 = g[2]
		if gn.y > 0.6:
			ground_n = gn

	var pos := Vector3(xz.x, y, xz.z)
	var follow := lerpf(air_follow_rise_speed, air_follow_speed, fall_t)
	f.planted = f.planted.lerp(pos, 1.0 - exp(-follow * delta))
	f.current = f.planted

	var body_up: Vector3 = _player_basis().y.normalized()
	if body_up.length_squared() < 0.0001:
		body_up = Vector3.UP

	var want_n := body_up.slerp(ground_n, _air_ext).normalized()
	f.current_normal = f.current_normal.slerp(want_n, 1.0 - exp(-air_follow_speed * delta)).normalized()
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

	_swing_idx = -1
	_swing_cooldown = 0.0
	_since_step = 1000.0


func _on_foot_plant(_f: Foot, was_recovery := false) -> void:
	var speed := Vector3(player.velocity.x, 0.0, player.velocity.z).length()
	var impact := clampf(step_impact + speed * step_impact_per_speed, 0.0, max_step_impact)

	impact *= lerpf(1.0, crouch_impact_scale, _crouch_amt)
	if was_recovery:
		impact *= 0.35

	_hips_vel -= impact


func _apply_foot(f: Foot, side_vec: Vector3, fwd: Vector3, delta: float) -> void:
	var want := _basis_from_normal(f.current_normal, fwd)
	var cur := f.target.global_basis.orthonormalized()
	var new_basis := cur.slerp(want, 1.0 - exp(-foot_turn_speed * delta))

	f.target.global_transform = Transform3D(new_basis.orthonormalized(), f.current)

	if f.pole:
		f.pole.global_position = _ik_hips() \
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


func _l() -> float:
	return _leg_len if _leg_len > 0.0 else max_leg_length


func _leg_root(slot: int) -> Vector3:
	if player.has_method("animated_leg_root"):
		return player.animated_leg_root(slot)

	return _ik_hips()


func _ik_hips() -> Vector3:
	if player.has_method("animated_hips_position"):
		return player.animated_hips_position()

	return _player_pos()


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


func _sample_ground(p: Vector3, down := 1.5) -> Array:
	var space := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		p + Vector3.UP * 0.6,
		p + Vector3.DOWN * down,
		ground_mask,
	)

	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return [false, NO_GROUND, Vector3.UP]

	var n: Vector3 = hit.normal
	if n.length_squared() < 0.0001:
		n = Vector3.UP

	return [true, hit.position.y, n.normalized()]
