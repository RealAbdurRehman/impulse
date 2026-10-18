class_name EnemyPilot
extends RefCounted
## Walks an enemy along the play plane. It reads the ground ahead the way the
## movement script does and decides in time: stairs and small steps are just
## walked, low obstacles and narrow gaps are jumped, and walls, ledges too deep
## to step off and gaps too wide to cross stop it and set `blocked`, so the brain
## can choose something else.
##
## A jump is timed, not just started: the body rises for a moment and is only
## above the obstacle for a short window, so the jump begins when the distance
## left to the edge is what the speed covers in the middle of that window. Too
## slow or too close (it started next to the obstacle, or missed once) and it
## backs off first and takes a run at it, instead of hopping at the foot of it.

const LOOK := 0.55
const STEP := 0.55
const WALL := 1.4
const ARRIVE := 0.3
const DEFAULT_DROP := 1.2
const ROUTE_DROP := 4.5
## How many route points ahead (0.25 m apart) it looks for the one it is nearest to.
const CATCH_UP := 24

## What the movement script won't let it get closer than: the wall check distance.
const CLOSEST := 0.5
## Fastest it walks without sprinting; above this height of obstacle it takes a run.
const RUN_AT := 0.65
const RUN_SPEED := 1.9
## How far (metres) it backs away to get a run at a jump: speed comes from distance.
const RUN_UP := 2.0

var body: CharacterMovement
var input: ActorInput

## Tallest obstacle it jumps, deepest ledge it steps off, widest gap it jumps (metres).
var jump_height := 0.9
var max_drop := DEFAULT_DROP
var jump_reach := 1.4

var blocked := false

## Running up to, taking, or backing off for a jump: it can't be aiming down
## sights (that would slow it) while this is true.
var committed := false

## The route being followed: (x, y, kind) points from EnemyNav.
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


## Call once a tick before steering: keeps a jump held long enough to reach full height.
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


## Follows the route; true once its last point is reached. It steps off ledges
## only where the route says to drop, and the usual probes jump the rest.
func follow(run: bool, delta: float) -> bool:
	var here := body.global_position
	_catch_up(here)
	while _next < route.size() and absf(route[_next].x - here.x) < ARRIVE and _reached(_next, here):
		_next += 1

	if _next >= route.size():
		max_drop = DEFAULT_DROP
		stop()
		return true

	var goal := route[_next]
	max_drop = ROUTE_DROP if int(goal.z) == EnemyNav.Kind.DROP else DEFAULT_DROP

	# A drop or jump is only done once it is under way: right above its landing
	# spot it keeps going the way it was heading until it is off the edge.
	var dx := goal.x - here.x
	if absf(dx) >= ARRIVE or int(goal.z) == EnemyNav.Kind.WALK:
		_heading = signf(dx) if dx != 0.0 else _heading

	walk(_heading, run, delta)
	return false


## Moves the pointer to the point of the next few metres of the route that the
## body is really nearest to, for when it got ahead of the pointer (it jumped
## over a stretch, or was walking by its own probes for a while): otherwise it
## would turn back for a point it has already passed.
func _catch_up(here: Vector3) -> void:
	var best := _next
	var best_distance := INF
	for i in range(_next, mini(_next + CATCH_UP, route.size())):
		var distance := absf(route[i].x - here.x) + absf(route[i].y - here.y) * 0.5
		if distance < best_distance:
			best_distance = distance
			best = i

	_next = best


## Whether the body is at route point `i`: level with it, or in the air above it
## or standing on what it jumped onto (the point is the spot it took off from).
func _reached(i: int, here: Vector3) -> bool:
	var rise := here.y - route[i].y
	if absf(rise) < 0.7 or not body.is_on_floor():
		return true

	return rise > 0.0 and i + 1 < route.size() and route[i + 1].y > route[i].y + 0.3


## Heads for x; true once it is there.
func steer(goal_x: float, run: bool, delta: float) -> bool:
	var dx := goal_x - body.global_position.x
	if absf(dx) < ARRIVE:
		stop()
		return true

	walk(signf(dx), run, delta)
	return false


## Walks in a direction (+1 or -1) until told otherwise. Once a leap is under
## way it goes the way it leapt, whatever the brain wants: it can't turn in the air.
## With `may_jump` off (shuffling about, backing off) gaps and obstacles just stop it.
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


## Steps back from an obstacle to get a run at it, as long as there is floor behind.
func _back_off(delta: float) -> void:
	_runup_left -= delta
	input.move = _runup_dir
	input.sprint = true
	blocked = false

	var x := body.global_position.x
	var behind := _surface(x + _runup_dir * 0.6, body.global_position.y)
	if is_nan(behind) or behind - body.global_position.y > STEP or absf(x - _runup_from) >= RUN_UP:
		_runup_left = 0.0
		input.move = 0.0


## Stops walking. A body slides on a little after the input stops (speed squared
## over 7 metres), so one that would slide off an edge carries on instead if it
## is fast enough to jump it, and brakes hard if not.
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

	var look := LOOK + speed * speed / 7.0
	var edge := _gap_edge(dir, x, feet, look)
	if edge < INF:
		if may_jump:
			_gap(dir, x, feet, edge, speed)
		else:
			_halt(true)

		return

	var wall := _obstacle(dir, x, feet, 0.6 + speed * 0.8 + 0.5)
	if wall.x < INF:
		if not may_jump or wall.y > WALL or wall.y > jump_height + 0.02:
			if wall.x < look:
				_halt()

			return

		_approach(dir, wall.x, wall.y, speed)
	elif may_jump and _gap_soon(dir, x, feet):
		input.sprint = true
		committed = true


## Distance to the near edge of the first obstacle ahead that is too tall to just
## step onto, and how high it is: Vector2(INF, 0) when there is none in `far`.
## An obstacle behind a step it has to climb first doesn't count yet: it is
## judged from the top of that step, once it is standing there.
func _obstacle(dir: float, x: float, feet: float, far: float) -> Vector2:
	var level := feet
	var climbed := false
	var s := 0.1
	while s <= far:
		var top := _surface(x + dir * s, feet)
		if not is_nan(top):
			if top - level > STEP:
				return Vector2(INF, 0.0) if climbed else Vector2(s, top - feet)

			climbed = climbed or top > feet + 0.2
			level = top

		s += 0.05

	return Vector2(INF, 0.0)


## An obstacle to jump, `edge` metres ahead and `rise` high. Tall ones are taken
## at a run. The jump goes when the speed will carry it to the edge in the middle
## of the time the body is high enough; if it isn't going fast enough (it began
## close to it, or missed once) it backs off for a run.
func _approach(dir: float, edge: float, rise: float, speed: float) -> void:
	committed = true
	if rise > RUN_AT:
		input.sprint = true

	# A low obstacle doesn't stop the body short of it (the wall check passes
	# over it), so it can walk right up and jump; a tall one holds it off.
	var blocks := rise >= body.max_step_up + 0.1
	var window := _window(rise)
	var aim := lerpf(window.x, window.y, 0.65)
	var launch := maxf(speed * aim, CLOSEST + 0.05 if blocks else 0.15)
	if edge > launch:
		return

	var arrives := edge / maxf(speed, 0.05)
	var slow := arrives > window.y + 0.05 or (rise > RUN_AT and speed < RUN_SPEED * 0.8 and edge < 1.2)
	if blocks and slow and _runups < 2 and _since_jump > 0.3:
		_start_runup(-dir)
		return

	_run_left = 0.8
	_jump(dir)


## The fastest the body goes in a direction: backwards it can only back-pedal.
func _top_speed(dir: float) -> float:
	if int(dir) != body.facing:
		return body.walk_speed * body.backpedal_speed_mult

	return body.run_speed


## Backs away for `time` seconds to get a run at it. Twice in a row without a
## jump is all it tries; a place where the run never gets fast enough is jumped
## from as is.
func _start_runup(dir: float) -> void:
	_runup_left = 4.0
	_runup_from = body.global_position.x
	_runup_dir = dir
	_runups += 1
	_since_runup = 0.0


## When the body is above a height (seconds after the jump starts): it rises
## past it at x, and falls back below it at y.
func _window(rise: float) -> Vector2:
	var v := body.jump_velocity
	var g := body.gravity
	var top := v * v / (2.0 * g)
	var need := minf(rise + 0.08, top - 0.02)
	var up := (v - sqrt(maxf(v * v - 2.0 * g * need, 0.0))) / g
	var down := v / g + sqrt(maxf(2.0 * (top - need) / (g * body.fall_gravity_mult), 0.0))
	return Vector2(up, down)


## Ground ends ahead: if there is ground within jump reach on the far side, run
## up to the edge (fast enough for the width) and jump, otherwise stop.
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


## Distance to the first place ahead with nothing to stand on (within `far`), or INF.
func _gap_edge(dir: float, x: float, feet: float, far: float) -> float:
	var s := 0.0
	while s <= far:
		if is_nan(_surface(x + dir * s, feet)):
			return s

		s += 0.1

	return INF


## How wide the gap is from its edge: the first ground at about foot level beyond.
func _gap_width(dir: float, x: float, feet: float, edge: float) -> float:
	var s := edge + 0.2
	while s <= edge + jump_reach:
		if not is_nan(_level(x + dir * s, feet)):
			return s - edge

		s += 0.1

	return jump_reach


## A gap coming up within a few steps that can be jumped: run at it, the jump
## carries further.
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


## Pulls up. At an edge it brakes against the way it is going if it is still
## moving, so it doesn't slide on over it.
func _halt(brake := false) -> void:
	var speed := body.velocity.x
	input.move = -signf(speed) if brake and absf(speed) > 0.3 else 0.0
	input.sprint = false
	blocked = true


## Top of whatever is under x between head height and max_drop below the feet, or NAN.
func _surface(x: float, feet: float) -> float:
	return _ray_down(x, feet + 1.6, feet - max_drop - 0.05)


## Ground at about the same height as the feet (a landing), or NAN.
func _level(x: float, feet: float) -> float:
	return _ray_down(x, feet + 0.6, feet - 0.5)


func _ray_down(x: float, from_y: float, to_y: float) -> float:
	var z := body.global_position.z
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, to_y, z), body.ground_mask)
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	return NAN if hit.is_empty() else (hit.position as Vector3).y


## Asked to move but going nowhere for a second: something is in the way (a
## character that won't give way, a wall the probes missed).
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
