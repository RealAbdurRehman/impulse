class_name GaitDriver
extends Node


class Foot:
	var side := 1.0

	var target: Node3D
	var pole: Node3D

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
	var duration := 0.3
	var lift := 0.1

	var air_role := 1.0

	var fdir := Vector3.RIGHT
	var start_dir := Vector3.RIGHT
	var end_dir := Vector3.RIGHT

	var stance_facing := 1


const NO_GROUND := -1.0e20
const PROBE_UP := 0.8

@export var player: Node3D

@export var left_foot_target: Node3D
@export var right_foot_target: Node3D

@export var left_knee_pole: Node3D
@export var right_knee_pole: Node3D

@export_flags_3d_physics var ground_mask: int = 1

@export_group("Rig")
@export var character_forward_local := Vector3(0, 0, 1)

@export var leg_length := 0.85
@export var hip_rest_height := 0.94

@export var ankle_height := 0.09
@export var foot_lateral := 0.12

@export var run_speed := 2.0

@export var foot_settle_speed := 30.0
@export var foot_turn_speed := 30.0
@export var normal_settle_speed := 24.0

@export_group("Stepping")
@export var step_time_walk := 0.30
@export var step_time_run := 0.30
@export var idle_step_time := 0.36

@export var trigger_walk := 0.30
@export var trigger_run := 0.40

@export var idle_trigger := 0.12

@export var lead_base := 0.08
@export var lead_time := 0.14

@export var lead_max := 0.34

@export var min_plant_time := 0.04

@export_range(0.3, 1.0) var stretch_release_t := 0.7

@export var trail_hip_drop := 0.08
@export var trail_hip_drop_stairs := 0.3

@export var step_height := 0.22
@export var run_step_height_scale := 1.3

@export var crouch_step_height := 0.17
@export var idle_step_lift := 0.04
@export var stair_clearance := 0.05

@export var max_step_rise := 0.62
@export var max_step_drop := 0.75

@export var edge_probe := 0.10
@export var edge_snap_threshold := 0.05

@export var idle_speed_threshold := 0.08

@export_range(0.5, 1.0) var cadence_scale := 0.95

@export_range(0.0, 0.6) var run_overlap := 0.45
@export_range(0.5, 1.0) var reach_ratio := 0.96

@export_group("Stairs")
@export var stairs_slope := 0.22
@export var stairs_probe := 0.35

@export var step_time_stairs := 0.31
@export var trigger_stairs := 0.11

@export_range(0.0, 1.0) var stairs_arc := 0.25
@export var stairs_lead_base := 0.04
@export var stairs_lead_time := 0.07

@export_group("Idle Stance")
@export var idle_front_range := Vector2(0.14, 0.55)
@export var idle_back_range := Vector2(-0.55, -0.14)

@export var idle_min_gap := 0.40
@export var idle_max_gap := 0.95

@export var idle_land_front := Vector2(0.24, 0.42)
@export var idle_land_back := Vector2(-0.42, -0.24)

@export var idle_shuffle := true
@export var idle_shuffle_interval := Vector2(4.0, 8.0)

@export var idle_max_hip_drop := 0.08
@export var idle_tolerance := 0.08
@export var idle_stairs_tolerance := 0.25

@export var idle_step_cooldown := 0.9

@export_group("Turning")
@export var turn_step_time := 0.26
@export var turn_step_lift := 0.06
@export var turn_step_max_speed := 0.1

@export_group("Foot Roll")
@export var toe_off_degrees := 28.0
@export var heel_strike_degrees := 12.0
@export_range(0.0, 0.95) var swing_align_start := 0.55

@export_group("Body")
@export var hip_half_width := 0.09
@export var crouch_blend_speed := 5.0

@export_range(0.5, 1.0) var idle_hip_ratio := 0.93
@export_range(0.5, 1.0) var walk_hip_ratio := 0.95
@export_range(0.5, 1.0) var run_hip_ratio := 0.90
@export_range(0.4, 1.0) var crouch_hip_ratio := 0.50

@export_group("Crouch")
@export var crouch_lean_degrees := 28.0

@export var crouch_foot_stagger := 0.22
@export var crouch_foot_lateral_extra := 0.04

@export var crouch_heel_lift := 0.08
@export var crouch_heel_pitch_degrees := 42.0

@export var crouch_hips_back := 0.07

@export var lean_speed := 5.0

@export var lean_max_degrees := 14.0
@export var lean_back_degrees := 2.5

@export var idle_sway := 0.0
@export var idle_sway_speed := 0.8

@export var hips_spring := 160.0
@export var hips_damping := 22.0

@export var step_impact := 0.18
@export var step_impact_per_speed := 0.04

@export_range(0.0, 1.0) var crouch_impact_scale := 0.15

@export_group("Air pose")
@export var air_follow_speed := 16.0

@export var air_hip_follow := 28.0
@export var air_bend_time := 0.22
@export var air_extend_time := 0.12
@export var air_extend_lead := 0.36
@export var air_blend_in_time := 0.08
@export var air_blend_out_time := 0.10

@export_range(0.3, 0.85) var air_hang_rising := 0.62
@export_range(0.3, 0.85) var air_hang_falling := 0.78

@export var air_lead_reach := 0.26
@export var air_lead_lift := 0.24
@export var air_trail_reach := 0.32
@export var air_trail_drop := 0.06

@export_range(0.0, 1.0) var air_standing_stride := 0.4

@export_group("Landing")
@export var landing_drop := 0.22
@export var landing_dip_speed := 1.3
@export var landing_ref_speed := 9.0
@export var landing_recover_time := 0.5

@export var landing_settle_time := 0.16

var lean_angle := 0.0
var lean_axis := Vector3.RIGHT
var hips_offset_y := 0.0

var landing_amount := 0.0

var foot_phase := 0.0
var speed_ratio := 0.0
var crouch_amount := 0.0
var air_amount := 0.0
var vertical_speed := 0.0

var stairs_amount := 0.0

var hips_offset_fwd := 0.0

var _feet: Array[Foot] = []

var _hip_y := 0.0
var _hip_vel := 0.0
var _hip_init := false

var _crouch_amt := 0.0
var _run_amt := 0.0
var _move_amt := 0.0
var _land_amt := 0.0
var _since_land := 1000.0

var _hang := 0.97
var _air_t := 0.0
var _air_split := 0.0
var _clock := 0.0
var _prev_vy := 0.0
var _was_on_floor := true

var _vel := Vector3.ZERO
var _plane_z := 0.0

var _last_step := -1
var _since_step_start := 10.0
var _idle_cd := 0.0

var _rng := RandomNumberGenerator.new()
var _shuffle_timer := 4.0


func _ready() -> void:
	if player == null:
		return

	_rng.randomize()
	_shuffle_timer = _rng.randf_range(idle_shuffle_interval.x, idle_shuffle_interval.y)

	_setup_feet.call_deferred()


func _setup_feet() -> void:
	if "run_speed" in player:
		run_speed = player.run_speed

	_plane_z = player.global_position.z

	_feet.append(_make_foot(left_foot_target, left_knee_pole, 1.0))
	_feet.append(_make_foot(right_foot_target, right_knee_pole, -1.0))

	var fwd := _fwd()
	for f in _feet:
		f.fdir = fwd
		f.start_dir = fwd
		f.end_dir = fwd
		f.stance_facing = int(_facing_sign())
		f.target.global_transform = Transform3D(
			_basis_from_normal(f.current_normal, fwd),
			f.current,
		)


func _make_foot(target: Node3D, pole: Node3D, side: float) -> Foot:
	var f := Foot.new()
	f.target = target
	f.pole = pole
	f.side = side

	target.top_level = true
	if pole:
		pole.top_level = true

	var base := player.global_position + _side_vec() * foot_lateral * side
	var g := _sample_ground(base)
	var y: float = g[1] if g[0] else player.global_position.y

	f.planted = Vector3(base.x, y + ankle_height, base.z)
	f.planted_normal = g[2] if g[0] else Vector3.UP
	f.current = f.planted
	f.current_normal = f.planted_normal

	return f


func _physics_process(delta: float) -> void:
	if player == null or _feet.size() < 2:
		return

	var on_floor: bool = player.is_on_floor()
	var move_speed := _pf("move_speed")
	var dirx := signf(_pf("move_dir"))

	var v: Variant = player.get("velocity")
	_vel = v if v is Vector3 else Vector3.ZERO

	var fwd := _fwd()
	var side_vec := _side_vec()
	var tfwd := _target_fwd()
	var tside := Vector3.UP.cross(tfwd).normalized()
	var crouching := on_floor and Input.is_action_pressed("crouch")

	_crouch_amt = move_toward(_crouch_amt, 1.0 if crouching else 0.0, crouch_blend_speed * delta)
	_since_land += delta
	_since_step_start += delta
	_idle_cd = maxf(_idle_cd - delta, 0.0)

	speed_ratio = clampf(move_speed / maxf(run_speed, 0.01), 0.0, 1.0)

	var run_target := 0.0
	if on_floor and not crouching:
		run_target = smoothstep(0.5, 1.0, speed_ratio)
	_run_amt = lerpf(_run_amt, run_target, 1.0 - exp(-6.0 * delta))

	var move_target := 0.0
	if on_floor and not crouching:
		move_target = clampf(move_speed / 0.6, 0.0, 1.0)
	_move_amt = lerpf(_move_amt, move_target, 1.0 - exp(-6.0 * delta))

	crouch_amount = _crouch_amt
	vertical_speed = _vel.y
	_clock += delta

	_update_stairs(delta, on_floor, dirx, fwd)
	_update_lean(delta, on_floor, move_speed, dirx, fwd)

	if on_floor and not _was_on_floor:
		_on_land()

	_land_amt = move_toward(_land_amt, 0.0, delta / maxf(landing_recover_time, 0.05))
	landing_amount = smoothstep(0.0, 1.0, _land_amt)

	if on_floor:
		_update_stepping(tside, tfwd, move_speed, dirx, delta)

		for f in _feet:
			_update_grounded_foot(f, delta)
	else:
		if _was_on_floor:
			_hang = clampf(_current_straightness(side_vec), 0.5, 0.99)
			_begin_air()

		_update_air_state(_vel.y, delta)

		for f in _feet:
			_update_air_foot(f, side_vec, fwd, delta)

	_update_hips(delta, on_floor)

	for f in _feet:
		_apply_foot(f, side_vec, fwd, delta)

	foot_phase = clampf(
		(_feet[0].current.x - _feet[1].current.x) * _facing_sign() / 0.35,
		-1.0,
		1.0,
	)

	if on_floor and player.has_method("drive_root"):
		var sy := 0.0
		for f in _feet:
			sy += _foot_support_y(f)

		player.drive_root(Vector3(0.0, sy * 0.5 - ankle_height, 0.0), delta)

	if on_floor:
		_air_t = move_toward(_air_t, 0.0, delta / maxf(air_blend_out_time, 0.02))
	else:
		_air_t = move_toward(_air_t, 1.0, delta / maxf(air_blend_in_time, 0.02))

	air_amount = smoothstep(0.0, 1.0, _air_t)

	_was_on_floor = on_floor
	_prev_vy = _vel.y


func _update_stepping(
	side_vec: Vector3,
	fwd: Vector3,
	move_speed: float,
	dirx: float,
	delta: float,
) -> void:
	var overlap := smoothstep(0.45, 1.0, speed_ratio) * run_overlap * (1.0 - stairs_amount)
	var moving := move_speed > idle_speed_threshold and dirx != 0.0

	var stretched_foot := false
	if moving:
		for f in _feet:
			if not f.swinging and _hip_pull(f) > _pull_limit():
				stretched_foot = true

	var gate := 1.0 - overlap
	if stretched_foot:
		gate = minf(gate, stretch_release_t)

	for f in _feet:
		if f.swinging and f.t < gate:
			return

	if not moving and _since_land < landing_settle_time and _land_amt > 0.05:
		return

	if overlap < 0.01 and _since_land < min_plant_time:
		return

	var root_x: float = player.global_position.x

	if move_speed < turn_step_max_speed and _update_turn(side_vec, fwd):
		return

	if not moving and _crouch_amt < 0.3:
		_update_idle_stance(side_vec, fwd, delta)
		return

	var best := -1
	var best_err := 0.0

	var beat := 0.0
	if moving and stairs_amount < 0.5:
		var thr0 := lerpf(trigger_walk, trigger_run, _run_ratio(move_speed))
		var dur0 := lerpf(step_time_walk, step_time_run, _run_ratio(move_speed))
		var land := _lead_for(move_speed)
		beat = ((thr0 + land) / maxf(move_speed, 0.1) + dur0) * 0.5 * cadence_scale

	for i in 2:
		var f := _feet[i]
		if f.swinging:
			continue

		var home_x := root_x + _stagger(f, fwd).x

		var err: float
		var thr: float
		if moving:
			err = (home_x - f.planted.x) * dirx
			thr = lerpf(trigger_walk, trigger_run, _run_ratio(move_speed))
			thr = lerpf(thr, trigger_stairs, stairs_amount)

			if beat > 0.0:
				var stretched := _hip_pull(f) > _pull_limit()

				if i == _last_step and err < thr * 1.5 and not stretched:
					continue

				var due := _since_step_start >= beat
				if due and err > thr * 0.3:
					thr = minf(thr, err - 0.001)
				elif _since_step_start < beat * 0.7 and err < thr * 1.4 and not stretched:
					continue
				elif stretched:
					thr = minf(thr, err - 0.001)
		else:
			err = absf(home_x - f.planted.x)
			thr = idle_trigger

		if err > thr and err > best_err:
			best_err = err
			best = i

	if best >= 0:
		_begin_step(best, side_vec, fwd, move_speed, dirx, moving)


func _update_turn(tside: Vector3, tfwd: Vector3) -> bool:
	var want := 1 if tfwd.x >= 0.0 else -1

	var pick := -1
	var best := INF
	for i in 2:
		var f := _feet[i]
		if f.stance_facing == want:
			continue

		var key := f.planted.x * float(want)
		if key < best:
			best = key
			pick = i

	if pick < 0:
		return false

	var f := _feet[pick]
	f.stance_facing = want
	_begin_step(pick, tside, tfwd, 0.0, 0.0, false, f.planted.x, true)
	_idle_cd = idle_step_cooldown

	return true


func _update_idle_stance(side_vec: Vector3, fwd: Vector3, delta: float) -> void:
	if _feet[0].swinging or _feet[1].swinging or _idle_cd > 0.0:
		return

	var fix := _idle_repair()

	if fix.is_empty() and idle_shuffle and _slope_between_feet() < 0.1:
		_shuffle_timer -= delta
		if _shuffle_timer <= 0.0:
			_shuffle_timer = _rng.randf_range(idle_shuffle_interval.x, idle_shuffle_interval.y)
			fix = _idle_shuffle()

	if fix.is_empty():
		return

	var fs := _facing_sign()
	var root_x: float = player.global_position.x
	_idle_cd = idle_step_cooldown
	_begin_step(fix[0], side_vec, fwd, 0.0, 0.0, false, root_x + float(fix[1]) * fs)


func _slope_between_feet() -> float:
	return clampf(absf(_feet[0].planted.y - _feet[1].planted.y) / 0.12, 0.0, 1.0)


func _idle_offsets() -> Array:
	var fs := _facing_sign()
	var root_x: float = player.global_position.x

	var o0 := (_feet[0].planted.x - root_x) * fs
	var o1 := (_feet[1].planted.x - root_x) * fs

	if o0 >= o1:
		return [0, o0, o1]

	return [1, o1, o0]


func _pull_limit() -> float:
	return lerpf(trail_hip_drop, trail_hip_drop_stairs, stairs_amount)


func _hip_pull(f: Foot) -> float:
	var dx: float = player.global_position.x - f.planted.x
	var dz := maxf(foot_lateral - hip_half_width, 0.0)
	var reach := leg_length * reach_ratio
	var max_y := f.planted.y + sqrt(maxf(reach * reach - dx * dx - dz * dz, 0.0))

	var support := 0.5 * (_foot_support_y(_feet[0]) + _foot_support_y(_feet[1]))
	return maxf(support + leg_length * idle_hip_ratio - max_y, 0.0)


func _idle_hip_drop(offset: float) -> float:
	var reach := leg_length * reach_ratio
	var dz := maxf(foot_lateral - hip_half_width, 0.0)
	var allow := sqrt(maxf(reach * reach - offset * offset - dz * dz, 0.0))

	return maxf(leg_length * idle_hip_ratio - allow, 0.0)


func _idle_broken(of: float, ob: float, slack: float) -> bool:
	if _idle_hip_drop(maxf(absf(of), absf(ob))) > idle_max_hip_drop + slack * 0.5:
		return true

	return (
		of > idle_front_range.y + slack or of < idle_front_range.x - slack
		or ob < idle_back_range.x - slack or ob > idle_back_range.y + slack
		or of - ob < idle_min_gap - slack or of - ob > idle_max_gap + slack
	)


func _idle_fits(idx: int, offset: float, slack: float) -> bool:
	var fs := _facing_sign()
	var root_x: float = player.global_position.x
	var f := _feet[idx]

	var plan := _plan_landing(f, root_x + offset * fs, fs, Vector3.UP.cross(_target_fwd()), _target_fwd(), root_x)
	var landed := ((plan[0] as Vector3).x - root_x) * fs
	var other := (_feet[1 - idx].planted.x - root_x) * fs

	return not _idle_broken(maxf(landed, other), minf(landed, other), slack)


func _idle_choose(idx: int, lo: float, hi: float, slack: float) -> Array:
	for i in 8:
		var off := _rng.randf_range(lo, hi)
		if _idle_fits(idx, off, slack):
			return [idx, off]

	return []


func _idle_repair() -> Array:
	var o := _idle_offsets()
	var front: int = o[0]
	var back := 1 - front
	var of: float = o[1]
	var ob: float = o[2]

	var slack := idle_tolerance + idle_stairs_tolerance * _slope_between_feet()
	if not _idle_broken(of, ob, slack):
		return []

	var res: Array
	if _idle_hip_drop(maxf(absf(of), absf(ob))) > idle_max_hip_drop + slack * 0.5:
		if absf(of) >= absf(ob):
			res = _idle_choose(front, idle_land_front.x, idle_land_front.y, slack)
		else:
			res = _idle_choose(back, idle_land_back.x, idle_land_back.y, slack)
	elif of > idle_front_range.y + slack or of < idle_front_range.x - slack:
		res = _idle_choose(front, idle_land_front.x, idle_land_front.y, slack)
	elif ob < idle_back_range.x - slack or ob > idle_back_range.y + slack:
		res = _idle_choose(back, idle_land_back.x, idle_land_back.y, slack)
	elif of - ob < idle_min_gap - slack:
		res = _idle_choose(back, of - 0.70, of - 0.50, slack)
	else:
		res = _idle_choose(front, ob + 0.55, ob + 0.80, slack)

	if res.is_empty():
		_idle_cd = idle_step_cooldown * 3.0

	return res


func _idle_shuffle() -> Array:
	var o := _idle_offsets()
	var front: int = o[0]
	var back := 1 - front

	if _rng.randf() < 0.5:
		var target := _pick(idle_land_front)
		if target - float(o[2]) >= idle_min_gap and _idle_fits(front, target, 0.0):
			return [front, target]
	else:
		var target := _pick(idle_land_back)
		if float(o[1]) - target >= idle_min_gap and _idle_fits(back, target, 0.0):
			return [back, target]

	return []


func _retarget_landing(f: Foot, k: float, delta: float) -> void:
	if f.recovery or stairs_amount > 0.1 or k > 0.85:
		return

	var dirx := signf(_pf("move_dir"))
	if dirx == 0.0:
		return

	var left := (1.0 - k) * f.duration
	var pred := _predict(left)
	if absf(pred.y - _pf("move_speed")) < 0.05:
		return

	var root_x: float = player.global_position.x
	var body_x := root_x + dirx * pred.x
	var target_x := body_x + dirx * _lead_for(pred.y)

	var dy := _hip_y - f.end.y
	var reach := leg_length * reach_ratio
	var dx_max := maxf(sqrt(maxf(reach * reach - dy * dy, 0.0)), 0.05)
	target_x = clampf(target_x, body_x - dx_max, body_x + dx_max)

	f.end.x = lerpf(f.end.x, target_x, 1.0 - exp(-12.0 * delta))


func _lead_for(speed: float) -> float:
	var a := lerpf(lead_base, stairs_lead_base, stairs_amount)
	var b := lerpf(lead_time, stairs_lead_time, stairs_amount)

	return minf(a + speed * b, lead_max)


func _predict(t: float) -> Vector2:
	var v := _pf("move_speed")
	var want := _pf("desired_speed")
	var rate := _pf("decel_ground")

	var want_dir := signf(_pf("desired_dir"))
	if want_dir != 0.0 and want_dir != signf(_pf("move_dir")) and v > 0.05:
		want = 0.0
		rate = _pf("turn_brake")
	elif want > v:
		rate = _pf("accel_ground")

	if rate < 0.01 or absf(want - v) < 0.001:
		return Vector2(v * t, v)

	var t_ramp := absf(want - v) / rate
	if t >= t_ramp:
		return Vector2((v + want) * 0.5 * t_ramp + want * (t - t_ramp), want)

	var v_end := v + signf(want - v) * rate * t
	return Vector2((v + v_end) * 0.5 * t, v_end)


func _pick(r: Vector2) -> float:
	return _rng.randf_range(r.x, r.y)


func _plan_landing(
	f: Foot,
	pred_x: float,
	d: float,
	side_vec: Vector3,
	fwd: Vector3,
	hip_x: float,
) -> Array:
	var lat := foot_lateral + crouch_foot_lateral_extra * _crouch_amt
	var want := Vector3(pred_x, 0.0, _plane_z) + side_vec * lat * f.side
	want.z += _stagger(f, fwd).z

	var fall := _footfall(want, d)
	var end_pos: Vector3 = fall[0]

	var back := signf(f.planted.x - want.x)
	var tries := 0
	while tries < 10:
		var dh: float = end_pos.y - f.planted.y
		if dh <= max_step_rise and dh >= -max_step_drop:
			break

		want.x += back * 0.08
		fall = _footfall(want, d)
		end_pos = fall[0]
		tries += 1

	var dy := _hip_y - end_pos.y
	var reach := leg_length * reach_ratio
	var dx_max := maxf(sqrt(maxf(reach * reach - dy * dy, 0.0)), 0.05)
	end_pos.x = clampf(end_pos.x, hip_x - dx_max, hip_x + dx_max)

	return [end_pos, fall]


func _begin_step(
	idx: int,
	side_vec: Vector3,
	fwd: Vector3,
	move_speed: float,
	dirx: float,
	moving: bool,
	forced_x := INF,
	turning := false,
) -> void:
	var f := _feet[idx]
	var root: Vector3 = player.global_position

	var dur := idle_step_time
	var travel := 0.0
	var pred_x := root.x + _stagger(f, fwd).x
	var d := dirx if dirx != 0.0 else _facing_sign()

	if moving:
		var rr := _run_ratio(move_speed)
		dur = lerpf(step_time_walk, step_time_run, rr)
		dur = lerpf(dur, step_time_stairs, stairs_amount)

		var pred := _predict(dur)
		travel = pred.x
		pred_x += dirx * (travel + _lead_for(pred.y))

	if forced_x != INF:
		pred_x = forced_x

	var hip_x := root.x + (dirx * travel if moving else 0.0)
	var plan := _plan_landing(f, pred_x, d, side_vec, fwd, hip_x)
	var end_pos: Vector3 = plan[0]
	var fall: Array = plan[1]

	_last_step = idx
	_since_step_start = 0.0

	f.start_dir = f.fdir
	f.end_dir = fwd
	f.stance_facing = 1 if fwd.x >= 0.0 else -1

	f.start = f.planted
	f.start_normal = f.current_normal
	f.end = end_pos
	f.end_normal = fall[1]
	f.duration = turn_step_time if turning else dur
	f.t = 0.0
	f.swinging = true
	f.recovery = not moving

	var lift := idle_step_lift
	if moving:
		lift = lerpf(step_height, step_height * run_step_height_scale, _run_ratio(move_speed))
	lift = lerpf(lift, crouch_step_height, _crouch_amt)
	if turning:
		lift = turn_step_lift

	var rise := f.end.y - f.start.y
	if absf(rise) > 0.04 and not turning:
		lift = stair_clearance + stairs_arc * step_height
		if rise < 0.0:
			lift *= 0.7
	f.lift = lift


func _update_grounded_foot(f: Foot, delta: float) -> void:
	if f.swinging:
		f.t += delta / maxf(f.duration, 0.001)
		var k := clampf(f.t, 0.0, 1.0)
		var rise := f.end.y - f.start.y

		_retarget_landing(f, k, delta)

		var hk := _smoother(clampf((k - 0.06) / 0.94, 0.0, 1.0))
		var vk := hk
		if rise > 0.03 and not f.recovery:
			hk = lerpf(hk, k, 0.5)
			vk = smoothstep(0.0, 0.7, k)
		elif rise < -0.03 and not f.recovery:
			hk = lerpf(hk, k, 0.5)
			vk = smoothstep(0.3, 1.0, k)

		var pos := Vector3(
			lerpf(f.start.x, f.end.x, hk),
			lerpf(f.start.y, f.end.y, vk),
			lerpf(f.start.z, f.end.z, hk),
		)
		var arc_k := k
		if rise > 0.03 and not f.recovery:
			arc_k = pow(k, 0.6)
		pos.y += sin(pow(arc_k, 0.75) * PI) * f.lift
		f.current = pos
		f.fdir = _turn_dir(f.start_dir, f.end_dir, smoothstep(0.1, 0.9, k))
		var fwd := f.fdir

		if k > swing_align_start:
			var nb := smoothstep(0.0, 1.0, (k - swing_align_start) / (1.0 - swing_align_start))
			f.current_normal = _blend_normal(f.start_normal, f.end_normal, nb)
		else:
			f.current_normal = f.start_normal

		if not f.recovery:
			var pitch := deg_to_rad(toe_off_degrees) \
					* smoothstep(0.0, 0.1, k) * (1.0 - smoothstep(0.1, 0.4, k))
			pitch -= deg_to_rad(heel_strike_degrees) \
					* smoothstep(0.6, 0.85, k) * (1.0 - smoothstep(0.9, 1.0, k))

			var n := f.current_normal
			var axis := n.cross(fwd)
			if axis.length_squared() > 0.0001:
				f.current_normal = n.rotated(axis.normalized(), pitch).normalized()

		if f.t >= 1.0:
			var was_recovery := f.recovery

			f.swinging = false
			f.recovery = false
			f.planted = f.end
			f.planted_normal = f.end_normal
			f.current = f.end
			f.current_normal = f.end_normal
			f.fdir = f.end_dir

			_on_plant(was_recovery)

		return

	var fwd := f.fdir
	var rear := _rear_amount(f)

	var g := _sample_ground(f.planted)
	if g[0]:
		f.planted.y = g[1] + ankle_height + crouch_heel_lift * rear
		var n: Vector3 = g[2]
		f.planted_normal = _blend_normal(
			f.planted_normal,
			n,
			1.0 - exp(-normal_settle_speed * delta),
		)

	var want_n := f.planted_normal
	if rear > 0.001:
		var axis := want_n.cross(fwd)
		if axis.length_squared() > 0.0001:
			want_n = want_n.rotated(axis.normalized(), deg_to_rad(crouch_heel_pitch_degrees) * rear)

	f.current = f.current.lerp(f.planted, 1.0 - exp(-foot_settle_speed * delta))
	f.current_normal = _blend_normal(f.current_normal, want_n, 1.0 - exp(-foot_turn_speed * delta))


func _on_plant(was_recovery: bool) -> void:
	var impact := clampf(step_impact + absf(_pf("move_speed")) * step_impact_per_speed, 0.0, 0.5)
	impact *= lerpf(1.0, crouch_impact_scale, _crouch_amt)
	if was_recovery:
		impact *= 0.35

	_hip_vel -= impact
	_since_land = 0.0


func _footfall(p: Vector3, d: float) -> Array:
	var dv := Vector3(d, 0.0, 0.0)
	var q := Vector3(p.x, player.global_position.y + 0.2, p.z)

	var toe := _sample_ground(q + dv * edge_probe)
	var heel := _sample_ground(q - dv * edge_probe)

	if toe[0] and heel[0]:
		var dy: float = toe[1] - heel[1]
		if absf(dy) > edge_snap_threshold:
			q += dv * (edge_probe * 1.2 * (1.0 if dy > 0.0 else -1.0))

	var g := _sample_ground(q)
	var y: float = g[1] if g[0] else player.global_position.y
	var n: Vector3 = g[2] if g[0] else Vector3.UP

	return [Vector3(q.x, y + ankle_height, q.z), n]


func _update_stairs(delta: float, on_floor: bool, dirx: float, _fwd: Vector3) -> void:
	var target := 0.0

	if on_floor:
		var d := dirx if dirx != 0.0 else _facing_sign()
		var root: Vector3 = player.global_position

		var here := _sample_ground(Vector3(root.x, root.y + 0.3, _plane_z))
		var ahead := _sample_ground(Vector3(root.x + d * stairs_probe, root.y + 0.3, _plane_z))

		if here[0] and ahead[0]:
			var slope := absf(float(ahead[1]) - float(here[1])) / maxf(stairs_probe, 0.05)
			target = 1.0 if slope > stairs_slope else 0.0

	stairs_amount = move_toward(stairs_amount, target, 5.0 * delta)


func _update_lean(
	delta: float,
	on_floor: bool,
	move_speed: float,
	dirx: float,
	fwd: Vector3,
) -> void:
	var target := 0.0

	if on_floor and move_speed > 0.05:
		var along := dirx * fwd.x
		var amount := (
			along
			if along > 0.0
			else along * (lean_back_degrees / maxf(lean_max_degrees, 0.01))
		)
		target = deg_to_rad(lean_max_degrees) * speed_ratio * amount

	target += deg_to_rad(crouch_lean_degrees) * _crouch_amt
	lean_angle = lerpf(lean_angle, target, 1.0 - exp(-lean_speed * delta))

	var f2 := Vector3(fwd.x, 0.0, fwd.z)
	if f2.length_squared() > 0.01:
		lean_axis = Vector3.UP.cross(f2.normalized()).normalized()


func _update_hips(delta: float, on_floor: bool) -> void:
	var root: Vector3 = player.global_position
	var target: float

	if on_floor:
		var yb := 0.0
		for f in _feet:
			yb += _foot_support_y(f)
		yb *= 0.5

		var ratio := lerpf(idle_hip_ratio, walk_hip_ratio, _move_amt)
		ratio = lerpf(ratio, run_hip_ratio, _run_amt)
		ratio = lerpf(ratio, crouch_hip_ratio, _crouch_amt)

		target = yb + leg_length * ratio - landing_drop * landing_amount
	else:
		target = root.y + hip_rest_height - 0.04

	var max_y := INF
	var reach := leg_length * reach_ratio
	for f in _feet:
		var dx: float = root.x - f.current.x
		var dz: float = maxf(foot_lateral - hip_half_width, 0.0)
		var allow := sqrt(maxf(reach * reach - dx * dx - dz * dz, 0.0))
		max_y = minf(max_y, f.current.y + allow)

	if on_floor:
		target = minf(target, max_y)

	if not _hip_init:
		_hip_y = target
		_hip_init = true

	if on_floor:
		_hip_vel += ((target - _hip_y) * hips_spring - _hip_vel * hips_damping) * delta
		_hip_vel = clampf(_hip_vel, -5.0, 5.0)
		_hip_y += _hip_vel * delta
	else:
		var ny := lerpf(_hip_y, target, 1.0 - exp(-air_hip_follow * delta))
		_hip_vel = clampf((ny - _hip_y) / maxf(delta, 0.0001), -5.0, 5.0)
		_hip_y = ny

	if on_floor and _hip_y > max_y:
		_hip_y = max_y
		_hip_vel = minf(_hip_vel, 0.0)

	hips_offset_y = _hip_y - (root.y + hip_rest_height)

	var still := (1.0 - _move_amt) * (1.0 - _crouch_amt) * (1.0 if on_floor else 0.0)
	hips_offset_fwd = (
		-crouch_hips_back * _crouch_amt + idle_sway * sin(_clock * TAU * idle_sway_speed) * still
	)


func _on_land() -> void:
	var impact := clampf(-_prev_vy / maxf(landing_ref_speed, 0.01), 0.0, 1.0)
	_land_amt = maxf(_land_amt, impact)
	_hip_vel -= impact * landing_dip_speed
	_since_land = 0.0

	for f in _feet:
		f.swinging = false
		f.recovery = false
		f.fdir = _target_fwd()
		f.stance_facing = int(_facing_sign())

		var g := _sample_ground(f.current)
		if g[0]:
			f.planted = Vector3(f.current.x, g[1] + ankle_height, f.current.z)
			f.planted_normal = g[2]
		else:
			f.planted = Vector3(f.current.x, player.global_position.y + ankle_height, f.current.z)
			f.planted_normal = Vector3.UP


func _foot_support_y(f: Foot) -> float:
	if f.swinging:
		return lerpf(f.start.y, f.end.y, smoothstep(0.3, 1.0, clampf(f.t, 0.0, 1.0)))

	return f.planted.y - crouch_heel_lift * _rear_amount(f)


func _current_straightness(side_vec: Vector3) -> float:
	var sum := 0.0
	for f in _feet:
		sum += (f.current - _hip_joint(f, side_vec)).length()

	return sum / (2.0 * maxf(leg_length, 0.01))


func _begin_air() -> void:
	_air_split = 0.0

	var d := signf(_vel.x) if absf(_vel.x) > 0.3 else _facing_sign()
	var lead_is_first := (_feet[0].current.x - _feet[1].current.x) * d >= 0.0

	_feet[0].air_role = 1.0 if lead_is_first else -1.0
	_feet[1].air_role = -_feet[0].air_role


func _update_air_state(vy: float, delta: float) -> void:
	var root: Vector3 = player.global_position
	var hip_y := root.y + hip_rest_height
	var floor_hit := _sample_ground(Vector3(root.x, hip_y, root.z), 4.0)

	var ext := 0.0
	var fall_speed := maxf(-vy, 0.0)
	if floor_hit[0] and fall_speed > 0.5:
		var slack: float = hip_y - (float(floor_hit[1]) + ankle_height)
		var tti := slack / maxf(fall_speed, 0.5)
		ext = (1.0 - smoothstep(0.14, air_extend_lead, tti)) * smoothstep(0.5, 2.0, fall_speed)

	var fall_t := clampf(0.5 - vy / 4.0, 0.0, 1.0)
	var bent := lerpf(air_hang_rising, air_hang_falling, fall_t)
	var want := lerpf(bent, 0.97, ext)

	var time := air_extend_time if want > _hang else air_bend_time
	_hang = lerpf(_hang, want, 1.0 - exp(-3.0 / maxf(time, 0.02) * delta))

	var run := clampf(absf(_vel.x) / maxf(run_speed, 0.01), 0.0, 1.0)
	var split := lerpf(air_standing_stride, 1.0, run) * (1.0 - 0.55 * ext)
	_air_split = lerpf(_air_split, split, 1.0 - exp(-10.0 * delta))


func _update_air_foot(f: Foot, side_vec: Vector3, fwd: Vector3, delta: float) -> void:
	f.swinging = false
	f.recovery = false
	f.fdir = _turn_dir(f.fdir, fwd, 1.0 - exp(-air_follow_speed * delta))
	f.stance_facing = int(_facing_sign())

	var hip := _hip_joint(f, side_vec)
	var dirx := signf(_vel.x) if absf(_vel.x) > 0.3 else _facing_sign()

	var lead := f.air_role > 0.0
	var reach := (air_lead_reach if lead else -air_trail_reach) * _air_split
	var lift := (air_lead_lift if lead else -air_trail_drop) * _air_split

	var pos := hip + Vector3(dirx * reach, -leg_length * _hang + lift, 0.0)

	var ground_n := Vector3.UP
	var g := _sample_ground(Vector3(pos.x, hip.y, pos.z))
	if g[0]:
		pos.y = maxf(pos.y, float(g[1]) + ankle_height)
		var gn: Vector3 = g[2]
		if gn.y > 0.6:
			ground_n = gn

	f.planted = f.planted.lerp(pos, 1.0 - exp(-air_follow_speed * delta))
	f.current = f.planted

	var want_n := _blend_normal(Vector3.UP, ground_n, smoothstep(0.9, 0.97, _hang))
	f.current_normal = _blend_normal(f.current_normal, want_n, 1.0 - exp(-air_follow_speed * delta))
	f.planted_normal = f.current_normal


func _apply_foot(f: Foot, side_vec: Vector3, fwd: Vector3, delta: float) -> void:
	var want := _basis_from_normal(f.current_normal, f.fdir)
	var cur := f.target.global_basis.orthonormalized()
	var b := cur.slerp(want, 1.0 - exp(-foot_turn_speed * delta))

	f.target.global_transform = Transform3D(b.orthonormalized(), f.current)

	if f.pole:
		f.pole.global_position = _hip_joint(f, side_vec) + Vector3.UP * 0.5 + fwd * 0.8


func _hip_joint(f: Foot, side_vec: Vector3) -> Vector3:
	var root: Vector3 = player.global_position
	var p := Vector3(root.x, _hip_y, _plane_z) + side_vec * foot_lateral * f.side
	return p


func _basis_from_normal(normal: Vector3, fwd: Vector3) -> Basis:
	var n := normal if normal.length_squared() > 0.0001 else Vector3.UP
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


func _is_front_foot(f: Foot) -> bool:
	return is_equal_approx(f.side, -_facing_sign())


func _crouch_stance() -> float:
	var walking := clampf(_pf("move_speed") / 0.45, 0.0, 1.0)
	return _crouch_amt * (1.0 - 0.85 * walking)


func _rear_amount(f: Foot) -> float:
	return 0.0 if _is_front_foot(f) else _crouch_stance()


func _stagger(f: Foot, fwd: Vector3) -> Vector3:
	var front := 1.0 if _is_front_foot(f) else -1.0
	return fwd * crouch_foot_stagger * _crouch_stance() * front


func _blend_normal(a: Vector3, b: Vector3, w: float) -> Vector3:
	var n := a.lerp(b, w)
	return n.normalized() if n.length_squared() > 0.0001 else b


func _turn_dir(a: Vector3, b: Vector3, w: float) -> Vector3:
	var ang := a.signed_angle_to(b, Vector3.UP)
	return a.rotated(Vector3.UP, ang * w).normalized()


func _run_ratio(v: float) -> float:
	return clampf((v - 0.5 * run_speed) / maxf(0.5 * run_speed, 0.01), 0.0, 1.0)


func _smoother(x: float) -> float:
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)


func _fwd() -> Vector3:
	return (player.global_basis.orthonormalized() * character_forward_local).normalized()


func _target_fwd() -> Vector3:
	if "facing" in player:
		return Vector3(float(player.facing), 0.0, 0.0)

	return _fwd()


func _side_vec() -> Vector3:
	return player.global_basis.orthonormalized().x.normalized()


func _facing_sign() -> float:
	var s := signf(_target_fwd().x)
	return s if s != 0.0 else 1.0


func _pf(prop: String) -> float:
	var v: Variant = player.get(prop)
	return float(v) if v != null else 0.0


func _sample_ground(p: Vector3, down := 1.5) -> Array:
	var space := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		p + Vector3.UP * PROBE_UP,
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
