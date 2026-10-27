class_name EnemyPilot
extends RefCounted

const LOOK_AHEAD := 0.55
const STEP_UP := 0.55
const WALL_HEIGHT := 1.4
const ARRIVE := 0.3
const DEFAULT_DROP := 1.2
const ROUTE_DROP := 4.5
const CATCH_UP := 24

const WALL_STANDOFF := 0.5
const RUN_AT_RISE := 0.65
const SPRINT_SPEED := 1.9
const RUN_UP := 2.0

var body: CharacterMovement
var input: ActorInput
var climber: StairClimber

var jump_height := 0.9
var max_drop := DEFAULT_DROP
var jump_reach := 1.4

var blocked := false

var committed := false

var route := PackedVector3Array()

var _next := 0
var _heading := 1.0

var _jump_left := 0.0
var _run_left := 0.0
var _leap_dir := 0.0
var _runup_left := 0.0
var _runup_from := 0.0
var _runup_dir := 0.0
var _since_jump := 9.0
var _runups := 0
var _since_runup := 9.0
var _check_left := 1.0
var _checked_x := 0.0


func tick(delta: float) -> void:
	_jump_left = maxf(_jump_left - delta, 0.0)
	_run_left = maxf(_run_left - delta, 0.0)
	_since_jump += delta
	_since_runup += delta
	if _since_runup > 6.0:
		_runups = 0

	input.jump = _jump_left > 0.0
	committed = false


func set_route(path: PackedVector3Array) -> void:
	route = path
	_next = 0
	blocked = false
	if not path.is_empty():
		_heading = signf(path[0].x - body.global_position.x) if path[0].x != body.global_position.x else _heading


func has_route() -> bool:
	return _next < route.size()


func follow(run: bool, delta: float) -> bool:
	if is_climbing():
		committed = true
		blocked = false
		return false

	var here := body.global_position
	_catch_up(here)
	while _next < route.size() and absf(route[_next].x - here.x) < ARRIVE and _reached(_next, here):
		_next += 1

	if _next >= route.size():
		max_drop = DEFAULT_DROP
		stop()
		return true

	var goal := route[_next]
	if int(goal.z) == EnemyNav.Kind.STAIR:
		return _stairs(goal, delta)

	max_drop = ROUTE_DROP if int(goal.z) == EnemyNav.Kind.DROP else DEFAULT_DROP

	var dx := goal.x - here.x
	if absf(dx) >= ARRIVE or int(goal.z) == EnemyNav.Kind.WALK:
		_heading = signf(dx) if dx != 0.0 else _heading

	walk(_heading, run, delta)
	return false


func is_climbing() -> bool:
	return climber != null and climber.climbing()


func _stairs(goal: Vector3, delta: float) -> bool:
	var link := _flight_to(goal)
	if link == null:
		blocked = true
		stop()
		return false

	var here := body.global_position
	var dx := link.global_position.x - here.x
	if absf(dx) < 0.3 and absf(link.global_position.y - here.y) < 0.6:
		if climber.begin(link):
			return false

		stop()
		blocked = false
		return false

	_heading = signf(dx)
	walk(_heading, false, delta, false)
	return false


func _flight_to(goal: Vector3) -> StairLink:
	var here := body.global_position
	var best: StairLink = null
	var best_gap := INF
	for node in body.get_tree().get_nodes_in_group(StairLink.GROUP):
		var link := node as StairLink
		if absf(link.goal_x() - goal.x) > 0.5 or absf(link.goal_y() - goal.y) > 0.6:
			continue

		var gap := absf(link.global_position.x - here.x) + absf(link.global_position.y - here.y)
		if gap < best_gap:
			best_gap = gap
			best = link

	return best


func _catch_up(here: Vector3) -> void:
	var best := _next
	var best_distance := INF
	for i in range(_next, mini(_next + CATCH_UP, route.size())):
		var distance := absf(route[i].x - here.x) + absf(route[i].y - here.y) * 0.5
		if distance < best_distance:
			best_distance = distance
			best = i

	_next = best


func _reached(i: int, here: Vector3) -> bool:
	var rise := here.y - route[i].y
	if absf(rise) < 0.7 or not body.is_on_floor():
		return true

	return rise > 0.0 and i + 1 < route.size() and route[i + 1].y > route[i].y + 0.3


func walk(dir: float, run: bool, delta: float, may_jump := true) -> void:
	if _run_left > 0.0 and not body.is_on_floor():
		dir = _leap_dir

	committed = _jump_left > 0.0 or _run_left > 0.0 or _runup_left > 0.0
	if _runup_left > 0.0:
		_back_off(delta)
		return

	input.move = dir
	input.sprint = run or _run_left > 0.0
	blocked = false

	if body.is_on_floor():
		_read_ground(dir, may_jump)
		if _runup_left > 0.0:
			_back_off(delta)

	_watch_progress(delta)


func _back_off(delta: float) -> void:
	_runup_left -= delta
	input.move = _runup_dir
	input.sprint = true
	blocked = false

	var x := body.global_position.x
	var behind := _surface(x + _runup_dir * 0.6, body.global_position.y)
	if is_nan(behind) or behind - body.global_position.y > STEP_UP or absf(x - _runup_from) >= RUN_UP:
		_runup_left = 0.0
		input.move = 0.0


func stop() -> void:
	var speed := body.velocity.x
	if body.is_on_floor() and absf(speed) > 0.3:
		var dir := signf(speed)
		var here := body.global_position
		var edge := _gap_edge(dir, here.x, here.y, speed * speed / 7.0 + 0.15)
		if edge < INF:
			if absf(speed) > 0.8 and _crossable(dir, here.x, here.y, edge):
				walk(dir, absf(speed) > 1.5, 1.0 / float(Engine.physics_ticks_per_second))
			else:
				input.move = -dir
				input.sprint = false

			return

	committed = _run_left > 0.0
	input.move = _leap_dir if committed else 0.0
	input.sprint = committed
	blocked = false


func _read_ground(dir: float, may_jump: bool) -> void:
	var feet := body.global_position.y
	var x := body.global_position.x
	var speed := absf(body.move_speed)

	var look := LOOK_AHEAD + speed * speed / 7.0
	var edge := _gap_edge(dir, x, feet, look)
	if edge < INF:
		if may_jump:
			_gap(dir, x, feet, edge, speed)
		else:
			_halt(true)

		return

	var wall := _obstacle(dir, x, feet, 0.6 + speed * 0.8 + 0.5)
	if wall.x < INF:
		if not may_jump or wall.y > WALL_HEIGHT or wall.y > jump_height + 0.02:
			if wall.x < look:
				_halt()

			return

		_approach(dir, wall.x, wall.y, speed)
	elif may_jump and _gap_soon(dir, x, feet):
		input.sprint = true
		committed = true


func _obstacle(dir: float, x: float, feet: float, far: float) -> Vector2:
	var level := feet
	var climbed := false
	var s := 0.1
	while s <= far:
		var top := _surface(x + dir * s, feet)
		if not is_nan(top):
			if top - level > STEP_UP:
				return Vector2(INF, 0.0) if climbed else Vector2(s, top - feet)

			climbed = climbed or top > feet + 0.2
			level = top

		s += 0.05

	return Vector2(INF, 0.0)


func _approach(dir: float, edge: float, rise: float, speed: float) -> void:
	committed = true
	if rise > RUN_AT_RISE:
		input.sprint = true

	var blocks := rise >= body.max_step_up + 0.1
	var window := _window(rise)
	var aim := lerpf(window.x, window.y, 0.65)
	var launch := maxf(speed * aim, WALL_STANDOFF + 0.05 if blocks else 0.15)
	if edge > launch:
		return

	var arrives := edge / maxf(speed, 0.05)
	var slow := arrives > window.y + 0.05 or (rise > RUN_AT_RISE and speed < SPRINT_SPEED * 0.8 and edge < 1.2)
	if blocks and slow and _runups < 2 and _since_jump > 0.3:
		_start_runup(-dir)
		return

	_run_left = 0.8
	_jump(dir)


func _top_speed(dir: float) -> float:
	if int(dir) != body.facing:
		return body.walk_speed * body.backpedal_speed_mult

	return body.run_speed


func _start_runup(dir: float) -> void:
	_runup_left = 4.0
	_runup_from = body.global_position.x
	_runup_dir = dir
	_runups += 1
	_since_runup = 0.0


func _window(rise: float) -> Vector2:
	var v := body.jump_velocity
	var g := body.gravity
	var top := v * v / (2.0 * g)
	var need := minf(rise + 0.08, top - 0.02)
	var up := (v - sqrt(maxf(v * v - 2.0 * g * need, 0.0))) / g
	var down := v / g + sqrt(maxf(2.0 * (top - need) / (g * body.fall_gravity_mult), 0.0))
	return Vector2(up, down)


func _gap(dir: float, x: float, feet: float, edge: float, speed: float) -> void:
	if not _crossable(dir, x, feet, edge):
		_halt(true)
		return

	var width := _gap_width(dir, x, feet, edge)
	var needed := (width + 0.3) / 0.83
	if speed < needed - 0.15 and _since_jump > 0.3:
		if _runups < 2 and _top_speed(dir) >= needed:
			_start_runup(-dir)
		else:
			_halt(true)

		return

	committed = true
	input.sprint = true
	if edge > 0.2:
		return

	_run_left = 1.0
	_jump(dir)


func _gap_edge(dir: float, x: float, feet: float, far: float) -> float:
	var s := 0.0
	while s <= far:
		if is_nan(_surface(x + dir * s, feet)):
			return s

		s += 0.1

	return INF


func _gap_width(dir: float, x: float, feet: float, edge: float) -> float:
	var s := edge + 0.2
	while s <= edge + jump_reach:
		if not is_nan(_level(x + dir * s, feet)):
			return s - edge

		s += 0.1

	return jump_reach


func _gap_soon(dir: float, x: float, feet: float) -> bool:
	var s := 1.0
	while s <= 2.4:
		if is_nan(_surface(x + dir * s, feet)):
			return _crossable(dir, x + dir * (s - 0.1), feet, 0.1)

		s += 0.2

	return false


func _crossable(dir: float, from_x: float, feet: float, edge: float) -> bool:
	var s := edge + 0.2
	while s <= edge + jump_reach:
		if not is_nan(_level(from_x + dir * s, feet)):
			return true

		s += 0.1

	return false


func _jump(dir: float) -> void:
	if _jump_left <= 0.0:
		_jump_left = 0.5
		_since_jump = 0.0
		_runups = 0
		_leap_dir = dir
		input.jump = true


func _halt(brake := false) -> void:
	var speed := body.velocity.x
	input.move = -signf(speed) if brake and absf(speed) > 0.3 else 0.0
	input.sprint = false
	blocked = true


func _surface(x: float, feet: float) -> float:
	return _ray_down(x, feet + 1.6, feet - max_drop - 0.05)


func _level(x: float, feet: float) -> float:
	return _ray_down(x, feet + 0.6, feet - 0.5)


func _ray_down(x: float, from_y: float, to_y: float) -> float:
	var z := body.global_position.z
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, to_y, z), body.ground_mask)
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	return NAN if hit.is_empty() else (hit.position as Vector3).y


func _watch_progress(delta: float) -> void:
	if input.move == 0.0:
		_check_left = 1.0
		_checked_x = body.global_position.x
		return

	_check_left -= delta
	if _check_left > 0.0:
		return

	_check_left = 1.0
	if absf(body.global_position.x - _checked_x) < 0.15:
		blocked = true

	_checked_x = body.global_position.x
