class_name EnemyInput
extends ActorInput

enum Mode { PATROL, SEARCH, COMBAT, CLEARED }
enum Plan { ENGAGE, COVER, FLANK }
enum Phase { GO, HIDE, PEEK }
enum Tactic { HOLD, ADVANCE, RETREAT, STRAFE }

const SUSPECT := 0.3
const HUNCH_HOLD := 1.5
const HUNCH_FADE := 0.2
const ALARM_TIME := 1.2
const OFFSCREEN_SIGHT := 0.15
const SHOUT_RANGE := 22.0
const WARY_TIME := 40.0
const WARY_SIGHT := 1.6
const BODY_STANDOFF := 1.0
const CONCEALED := 0.2
const CONCEALED_REACH := 2.5
const FADE_TIME := 1.2
const SETTLE := 0.25
const PAINT_TIME := 1.4
const CLOSE_ENOUGH := 1.5
const SIDE_LIMIT := 3
const MIN_VIEW_REACH := 3.0
const SPACING := 1.3
const ROOM_RADIUS := 3.0
const SEARCH_AHEAD := 4.0
const SEARCH_BEHIND := 3.0
const CORPSE_STANDOFF := 1.8
const CLEARED_RANGE := 15.0

@export var target: CharacterMovement
@export var carrier: WeaponCarrier
@export var health: Health

@export_group("Personality")
## AUTO picks one that suits the gun; each enemy still varies around it.
@export var archetype := EnemyTraits.Archetype.AUTO
@export var skill_range := Vector2(0.25, 0.85)
## 0 = different every run.
@export var random_seed := 0

@export_group("Senses")
@export var sight_range := 20.0
## Half the angle (degrees) of the cone it sees in, up and down from the way it faces.
@export var view_angle := 55.0
## Sees anything this close even with its back turned.
@export var rear_awareness := 1.5
## Seconds it keeps heading for where it last saw the target before it searches.
@export var memory_time := 5.0
@export var search_time := 5.0
## Seconds between noticing the target and the first shot (varies with skill).
@export var reaction_time := 0.6
## Shows a "?" while it is suspicious and a "!" when it spots you.
@export var show_mark := true

@export_group("Patrol")
@export var roam_radius := 5.0
@export var idle_time := Vector2(1.5, 4.5)

@export_group("Combat")
## Range it likes to fight at, by gun, in metres; each enemy scales it by its nature.
@export var shotgun_range := Vector2(2.5, 6.0)
@export var sniper_range := Vector2(14.0, 26.0)
@export var rifle_range := Vector2(6.0, 13.0)
@export var pistol_range := Vector2(4.5, 10.0)
## Beyond this it raises the gun to its eye before shooting (smaller spread).
@export var scope_distance := 4.5

@export_group("Fair play")
## Holds fire while the player's camera doesn't show it (unless it has been shot),
## and keeps to ranges the picture covers.
@export var fair_play := true
## How far outside the picture (metres) it still counts as seen.
@export var fair_margin := 0.3
## Seconds after appearing before it notices anything.
@export var spawn_grace := 1.5

@export_group("Tactics")
## How far it looks for cover and for a flanking route, in metres.
@export var cover_search := 14.0
@export var flank_search := 30.0
@export var flank_limit := 40.0
## How far around its spawn point the level is mapped for routes and cover.
@export var map_extent := 200.0

var traits: EnemyTraits

var engaged := false

var hostile := true

var hunt := false

var awareness := 0.0

var patrol := PackedVector3Array()

var _mode := Mode.PATROL
var _plan := Plan.ENGAGE
var _phase := Phase.GO
var _tactic := Tactic.HOLD
var _tactic_left := 0.0
var _strafe := 1.0

var _rng := RandomNumberGenerator.new()
var _body: CharacterMovement
var _pilot: EnemyPilot
var _senses: EnemySenses
var _gunner: EnemyGunner
var _cover: EnemyCover
var _nav: EnemyNav
var _target_health: Health

var _visible := false
var _view_gain := 0.0
var _screen_gain := 1.0
var _hear := 0.0
var _view_slope := 1.0
var _quiet_for := 0.0
var _alerted := false
var _alarm_left := 0.0
var _pause_left := 0.0
var _call_left := 0.0
var _call_at := Vector3.ZERO
var _call_dir := 0.0
var _call_body := 0
var _body_target := 0
var _search_body := 0
var _inspected: EnemyInput
var _inspect_left := 0.0
var _cleaning := false
var _concealment := 1.0
var _wary_left := 0.0
var _bodies_seen := { }

static var _claimed := { }
var _post := 1
var _noise: NoiseSource
var _mark: EnemyMark
var _look_left := 0.0
var _known := false
var _last_seen := Vector3.ZERO
var _since_seen := 0.0
var _unseen_for := 99.0
var _react_left := 0.0
var _hurt_left := 0.0
var _pain := 0.0
var _first_contact := false
var _crouching := false

var _home := Vector3.ZERO
var _goal := Vector3.ZERO
var _wait_left := 0.0
var _glance := 0.0
var _glance_left := 0.0
var _search_left := 0.0
var _search_origin := Vector3.ZERO
var _search_at := Vector3.ZERO
var _search_stage := 0
var _last_dir := 0.0
var _hit_ms := -100000
var _killer := false
var _approaching := false
var _cleared_left := 0.0
var _corpse: Node3D
var _stalled := 0.0

var _route_goal := Vector2(NAN, NAN)
var _route_left := 0.0
var _travel_failed := false

var _decide_left := 0.0
var _spot := Vector2.ZERO
var _hide_left := 0.0
var _peek_left := 0.0
var _peek_rounds := 0
var _check_left := 0.0
var _cover_cycles := 0
var _settle_left := 0.0
var _flank_cooldown := 0.0
var _plan_age := 0.0

var _age := 0.0
var _on_screen := true
var _fair_on := false
var _view_reach := INF
var _provoked_left := 0.0
var _hidden := false
var _side_full := false

var _laser: EnemyLaser
var _paint_for := 0.0
var _painting := false

var _reload_left := 0.0
var _scoped_for := 0.0
var _still_for := 0.0
var _spread := 0.0
var _room := 0.0
var _follow := Vector2(INF, INF)
var _around_left := 0.0
var _shot := EnemySenses.Shot.CLEAR
var _shot_left := 0.0


func _ready() -> void:
	if random_seed != 0:
		_rng.seed = random_seed
	else:
		_rng.randomize()

	_body = get_parent() as CharacterMovement
	_view_slope = tan(deg_to_rad(view_angle))
	_target_health = target.get_node("Health") as Health
	_noise = NoiseSource.of(target)
	_noise.bang.connect(_on_bang)

	if show_mark:
		_mark = EnemyMark.new()
		_body.add_child.call_deferred(_mark)

	traits = EnemyTraits.roll(_rng, archetype, carrier.weapon.stats, skill_range)

	_pilot = EnemyPilot.new()
	_pilot.body = _body
	_pilot.input = self

	_senses = EnemySenses.new()
	_senses.body = _body
	_senses.health = health

	_gunner = EnemyGunner.new()
	_gunner.rng = _rng
	_gunner.skill = traits.skill
	_gunner.discipline = traits.discipline
	_gunner.patience = traits.patience
	_gunner.composure = traits.composure

	_cover = EnemyCover.new()
	_cover.senses = _senses
	_cover.rng = _rng

	if _is_sniper():
		_laser = EnemyLaser.new(_body)

	add_to_group(&"enemies")
	_home = _body.global_position
	_goal = _home
	_wait_left = _rng.randf_range(idle_time.x, idle_time.y)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	carrier.weapon.bullet_traced.connect(_on_traced)


func poll() -> void:
	var delta := get_physics_process_delta_time()
	if _nav == null:
		_nav = EnemyNav.of(_body, _body.ground_mask, map_extent)
		_cover.nav = _nav

	fire = false
	aim = false
	has_aim = false
	reload = false
	move = 0.0
	sprint = false
	crouch = false
	_age += delta
	_hurt_left = maxf(_hurt_left - delta, 0.0)
	_provoked_left = maxf(_provoked_left - delta, 0.0)
	_painting = false
	_since_seen += delta
	_flank_cooldown = maxf(_flank_cooldown - delta, 0.0)
	engaged = false

	_pilot.tick(delta)
	_sense(delta)
	_look_around(delta)

	match _mode:
		Mode.PATROL:
			_patrol(delta)
		Mode.SEARCH:
			_search(delta)
		Mode.COMBAT:
			_combat(delta)
		Mode.CLEARED:
			_cleared(delta)

	_reload(delta)

	if not sprint:
		move *= traits.pace

	if _laser != null and not _painting:
		_paint_for = 0.0
		_laser.hide()

	_crouching = crouch


func describe() -> String:
	var weapon := carrier.weapon
	var line := "%s  skill %.2f" % [EnemyTraits.Archetype.keys()[traits.archetype], traits.skill]
	var doing: String = Mode.keys()[_mode]
	if _mode == Mode.PATROL or _mode == Mode.SEARCH:
		doing += " %d%%%s" % [roundi(awareness * 100.0), " wary" if _wary_left > 0.0 else ""]
	else:
		doing = Plan.keys()[_plan] + (" (unseen)" if _hidden else "")
		if _plan == Plan.COVER:
			doing += " " + Phase.keys()[_phase]
		elif _plan == Plan.ENGAGE:
			doing += " " + Tactic.keys()[_tactic]

	return "%s\n%s\nammo %d/%d" % [line, doing, weapon.ammo, weapon.stats.magazine_size]


func _exit_tree() -> void:
	EnemyCover.release(get_instance_id())


func _on_traced(_from: Vector3, _to: Vector3, hit: Dictionary) -> void:
	if not hit.is_empty() and Health.of(hit.collider) == _target_health:
		_hit_ms = Time.get_ticks_msec()


func _on_died() -> void:
	EnemyCover.release(get_instance_id())
	if _mark != null:
		_mark.hide()

	if _laser != null:
		_laser.hide()


func _sense(delta: float) -> void:
	if not hostile or not _target_health.alive:
		_known = false
		_visible = false
		_alerted = false
		awareness = 0.0
		_hear = 0.0
		if _mark != null:
			_mark.show_state(0.0, false)

		if hostile and _mode == Mode.COMBAT:
			_stand_down()
		elif _mode != Mode.PATROL and _mode != Mode.CLEARED:
			_leave_combat()
			_mode = Mode.PATROL
			_goal = _body.global_position

		return

	if _age < spawn_grace:
		return

	var me := _body.global_position
	var there := target.global_position
	var distance := absf(there.x - me.x)

	_alarm_left = maxf(_alarm_left - delta, 0.0)
	_wary_left = maxf(_wary_left - delta, 0.0)
	_look_left -= delta
	if _look_left <= 0.0:
		_look_left = _rng.randf_range(0.08, 0.14)
		_look_screen()
		_screen_gain = 1.0 if _on_screen or _laser != null else OFFSCREEN_SIGHT
		_concealment = StealthZone.at(there + Vector3.UP * 0.9)
		_view_gain = _glimpse(me, there)
		_visible = _view_gain > 0.0
		_hear = _loudness(there, _noise.radius) if _noise.radius > 0.0 else 0.0
		if _mode == Mode.PATROL or _mode == Mode.SEARCH:
			_look_for_bodies(me)

		if _mark != null:
			_mark.show_state(awareness if _mode != Mode.COMBAT else 0.0, _alarm_left > 0.0)

	if _visible and _unseen_for > 1.5 and _known:
		_notice()

	_unseen_for = 0.0 if _visible else _unseen_for + delta
	if _visible:
		_last_seen = there
		_since_seen = 0.0
		if absf(target.velocity.x) > NoiseSource.MOVE_SPEED:
			_last_dir = signf(target.velocity.x)

	if _call_left > 0.0:
		_call_left -= delta
		if _call_left <= 0.0 and _mode != Mode.COMBAT:
			awareness = maxf(awareness, SUSPECT * 2.0)
			_last_seen = _call_at + Vector3(_rng.randfn(0.0, 1.5) if _call_body == 0 else 0.0, 0.0, 0.0)
			_last_dir = _call_dir
			_body_target = _call_body
			_wary_left = WARY_TIME
			_since_seen = 0.0

	var gain := 0.0
	if _visible:
		gain = _sight_rate(distance) * _view_gain * _screen_gain
	elif _hear > 0.0:
		gain = _hear * 0.8 * traits.alertness
		var heard := there + Vector3(_rng.randfn(0.0, (1.0 - _hear) * 1.5), 0.0, 0.0)
		if _mode == Mode.PATROL or _last_seen.distance_to(heard) > 2.0:
			_last_seen = heard
			_since_seen = 0.0

	if _mode == Mode.COMBAT:
		awareness = 1.0
	elif gain > 0.0:
		awareness = minf(awareness + gain * delta, 1.0)
		_quiet_for = 0.0
	else:
		_quiet_for += delta
		if _quiet_for > HUNCH_HOLD:
			awareness = maxf(awareness - HUNCH_FADE * delta, 0.45 if _mode == Mode.SEARCH else 0.0)

	if hunt or (_alerted and distance < traits.tracking):
		_last_seen = there
		_since_seen = 0.0
		if not _known:
			_alarm(there)
	elif awareness >= 1.0 and not _known:
		_alarm(_last_seen)
	elif awareness >= SUSPECT and _mode == Mode.PATROL:
		_start_search()
		_pause_left = _rng.randf_range(0.5, 1.1)
		_pilot.stop()


func _glimpse(me: Vector3, there: Vector3) -> float:
	var reach := there.x - me.x
	if absf(reach) >= sight_range:
		return 0.0

	var eye := me + Vector3.UP * (EnemyCover.CROUCH_EYE if _crouching else EnemyCover.EYE)
	var crouched := target.crouching
	var chest := there + Vector3.UP * (0.6 if crouched else 1.2)
	var head := there + Vector3.UP * (1.0 if crouched else 1.6)
	var ahead := reach * float(_body.facing)
	if _concealment < CONCEALED and absf(reach) > CONCEALED_REACH:
		return 0.0

	var gain := 0.0
	if _mode == Mode.COMBAT or (ahead > 0.0 and absf(chest.y - eye.y) <= ahead * _view_slope):
		gain = 1.0
	elif absf(reach) < rear_awareness:
		gain = 0.5

	if gain > 0.0 and not (_senses.sees(eye, chest) or _senses.sees(eye, head)):
		return 0.0

	return gain


func _sight_rate(distance: float) -> float:
	var near := 1.0 - clampf(distance / sight_range, 0.0, 1.0)
	var rate := 0.12 + 2.9 * pow(near, 2.5)
	var speed := absf(target.velocity.x)
	if target.crouching:
		rate *= 0.6

	if speed > NoiseSource.RUN_SPEED:
		rate *= 1.4
	elif speed < NoiseSource.MOVE_SPEED:
		rate *= 0.7

	if _mode == Mode.SEARCH:
		rate *= 2.5
	elif awareness >= SUSPECT:
		rate *= 1.5

	if _wary_left > 0.0:
		rate *= WARY_SIGHT

	rate *= _concealment

	return rate * traits.alertness


func _loudness(at: Vector3, radius: float) -> float:
	var me := _body.global_position
	var far := absf(at.x - me.x) + absf(at.y - me.y) * 1.5
	if far >= radius:
		return 0.0

	if not _senses.sees(me + Vector3.UP * EnemyCover.EYE, at + Vector3.UP * 1.2):
		far *= 1.5

	return clampf(1.0 - far / radius, 0.0, 1.0)


func _on_bang(at: Vector3, radius: float) -> void:
	if not hostile or not health.alive or _age < spawn_grace or not _target_health.alive:
		return

	var loud := _loudness(at, radius)
	if loud <= 0.0:
		return

	var heard := at + Vector3(_rng.randfn(0.0, (1.0 - loud) * 3.0), 0.0, 0.0)
	if _mode == Mode.COMBAT:
		if not _visible and _since_seen > 1.0:
			_last_seen = heard
			_since_seen = 0.0

		return

	awareness = minf(awareness + (0.3 + loud * 1.2) * traits.alertness, 1.0)
	_quiet_for = 0.0
	_last_seen = heard
	_since_seen = 0.0
	if awareness >= 1.0:
		_alarm(heard)


func _alarm(at: Vector3) -> void:
	awareness = 1.0
	_known = true
	_alerted = true
	_last_seen = at
	_since_seen = 0.0
	_alarm_left = ALARM_TIME
	_pause_left = 0.0
	_notice(0.6)
	_mode = Mode.COMBAT
	_plan = Plan.ENGAGE
	_tactic_left = 0.0
	_decide_left = 0.0
	_shout(at)


func _look_for_bodies(me: Vector3) -> void:
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var other := node as EnemyInput
		var id := other.get_instance_id()
		if other.health.alive or other.health.team != health.team or _bodies_seen.has(id):
			continue

		var spot := (other.health.ragdoll.get_child(0) as Node3D).global_position
		var reach := spot.x - me.x
		var eye := me + Vector3.UP * (EnemyCover.CROUCH_EYE if _crouching else EnemyCover.EYE)
		var ahead := reach * float(_body.facing)
		var in_cone := ahead > 0.0 and absf(spot.y - eye.y) <= ahead * _view_slope
		if absf(reach) < sight_range and (in_cone or absf(reach) < rear_awareness) and _senses.sees(eye, spot + Vector3.UP * 0.3):
			_find_body(id, spot)
			return


func _find_body(id: int, spot: Vector3) -> void:
	_bodies_seen[id] = true
	_wary_left = WARY_TIME
	awareness = maxf(awareness, SUSPECT * 2.0)
	_quiet_for = 0.0
	_last_seen = spot
	_since_seen = 0.0
	_last_dir = signf(spot.x - _body.global_position.x)
	_body_target = id
	_start_search()
	_pause_left = _rng.randf_range(0.6, 1.2)
	_pilot.stop()
	_shout(spot, id)


func _shout(at: Vector3, body := 0) -> void:
	var me := _body.global_position
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var other := node as EnemyInput
		if other == self or not other.health.alive or other.health.team != health.team:
			continue

		var there := other._body.global_position
		var far := absf(there.x - me.x) + absf(there.y - me.y) * 1.5
		if far < SHOUT_RANGE and other._mode != Mode.COMBAT:
			other._call_left = 0.4 + far * 0.04 + _rng.randf_range(0.0, 0.4)
			other._call_at = at
			other._call_dir = signf(at.x - there.x)
			other._call_body = body
			if body != 0:
				other._bodies_seen[body] = true


func _look_screen() -> void:
	var cam := get_viewport().get_camera_3d()
	_fair_on = fair_play and target.health.team == &"player"
	if not _fair_on:
		_on_screen = true
		_view_reach = INF
		_hidden = false
		return

	var chest := _body.global_position + Vector3.UP
	var seen := false
	for dx: float in [0.0, -fair_margin, fair_margin]:
		seen = seen or cam.is_position_in_frustum(chest + Vector3.RIGHT * dx)

	if seen and not _on_screen and _mode == Mode.COMBAT:
		_react_left = maxf(_react_left, _reaction())

	_on_screen = seen
	_hidden = not (seen or _provoked_left > 0.0)

	var size := get_viewport().get_visible_rect().size
	var depth := absf(cam.global_position.z - _body.global_position.z)
	_view_reach = maxf(depth * tan(deg_to_rad(cam.fov) * 0.5) * size.x / size.y * 0.9, MIN_VIEW_REACH)


func _reaction() -> float:
	return reaction_time * lerpf(1.5, 0.5, traits.skill) * _rng.randf_range(0.7, 1.3)


func _walks_in() -> bool:
	return _hidden and _laser == null


func _is_sniper() -> bool:
	var stats := carrier.weapon.stats
	return stats.manual_cycle and stats.pellets <= 1


func _notice(scale := 1.0) -> void:
	_react_left = _reaction() * scale
	_first_contact = true
	_gunner.look_ahead(_body.global_position + Vector3.UP * 1.35, _body.facing)


func _on_damaged(amount: float, _point: Vector3, _direction: Vector3, _bone: PhysicalBone3D) -> void:
	if not hostile or not _target_health.alive:
		return

	if _mode != Mode.COMBAT:
		_alarm_left = ALARM_TIME

	awareness = 1.0
	_alerted = true
	_known = true
	_last_seen = target.global_position
	_since_seen = 0.0
	_provoked_left = 4.0
	_hidden = false
	_pain += amount / health.max_health
	_hurt_left = _rng.randf_range(0.2, 0.5) * lerpf(1.4, 0.5, traits.composure)
	_gunner.flinch(absf(target.global_position.x - _body.global_position.x))

	if _mode != Mode.COMBAT:
		_mode = Mode.COMBAT
		_plan = Plan.ENGAGE
		_decide_left = 0.0


func _leave_combat() -> void:
	EnemyCover.release(get_instance_id())
	_plan = Plan.ENGAGE
	_pilot.set_route(PackedVector3Array())


func _travel(goal: Vector2, run: bool, delta: float, keep_off_target := false) -> bool:
	var me := _body.global_position
	_route_left -= delta
	_travel_failed = false

	var stale := not _pilot.has_route() or _route_goal.distance_to(goal) > 0.8 or (_pilot.blocked and _route_left <= 0.0)
	if stale:
		var from := _nav.nearest(me.x, me.y)
		var to := _nav.nearest(goal.x, goal.y)
		var path := PackedVector3Array()
		if keep_off_target:
			path = _nav.route(from, to, target.global_position.x, 1.6, target.global_position.y)
		else:
			path = _nav.route(from, to)

		if path.is_empty() and from != to:
			_travel_failed = true
			_pilot.stop()
			return false

		_pilot.set_route(path)
		_route_goal = goal
		_route_left = 1.0

	return _pilot.follow(run, delta)


func _patrol(delta: float) -> void:
	if _wait_left > 0.0:
		_wait_left -= delta
		_idle_look(delta, Vector2(2.5, 6.0))
		_stand(delta)
		if _wait_left <= 0.0:
			_goal = _next_post()

		return

	var arrived := _travel(Vector2(_goal.x, _goal.y), false, delta)
	if arrived or _travel_failed or _pilot.blocked:
		_wait_left = _rng.randf_range(idle_time.x, idle_time.y)
		_goal = _body.global_position


func _next_post() -> Vector3:
	if patrol.size() < 2:
		return _roam_spot()

	var spot := patrol[_post]
	_post = (_post + 1) % patrol.size()
	return spot


func _roam_spot() -> Vector3:
	var spots := _nav.spots_between(_home.x - roam_radius, _home.x + roam_radius)
	if spots.is_empty():
		return _body.global_position

	var id := spots[_rng.randi() % spots.size()]
	return Vector3(_nav.xs[id], _nav.ys[id], 0.0)


func _idle_look(delta: float, pause := Vector2(1.0, 3.0)) -> void:
	_glance_left -= delta
	if _glance_left <= 0.0:
		_glance_left = _rng.randf_range(pause.x, pause.y)
		_glance = 0.0 if _rng.randf() < 0.3 else (1.0 if _rng.randf() < 0.5 else -1.0)

	if _glance != 0.0:
		_look_toward(_glance)


func _look_toward(side: float) -> void:
	if absf(_body.velocity.x) < 0.5:
		has_aim = true
		aim_point = _body.global_position + Vector3(side * 10.0, 1.4, 0.0)


func _start_search() -> void:
	_mode = Mode.SEARCH
	_search_origin = _last_seen
	_search_at = _last_seen
	_search_stage = 0
	_search_left = 0.0
	_inspect_left = 0.0
	_search_body = _body_target
	if _search_body != 0:
		_search_at.x = _last_seen.x - signf(_last_seen.x - _body.global_position.x) * BODY_STANDOFF

	_body_target = 0


func _search(delta: float) -> void:
	if _since_seen < 0.5 and _last_seen.distance_to(_search_origin) > 3.0:
		_start_search()

	if _pause_left > 0.0:
		_pause_left -= delta
		_stand(delta)
		if not _look_at_body():
			_look_toward(signf(_search_at.x - _body.global_position.x))

		return

	if _inspect_left > 0.0:
		_inspect_left -= delta
		_stand(delta)
		_look_at_body()
		crouch = _cleaning
		if _inspect_left <= 0.0:
			if _cleaning and is_instance_valid(_inspected):
				_inspected.vanish()

			_search_left = search_time * 0.4 * _rng.randf_range(0.7, 1.3)

		return

	if _search_left > 0.0:
		_search_left -= delta
		_idle_look(delta, Vector2(0.5, 1.2))
		_stand(delta)
		if _search_left <= 0.0:
			_search_on()

		return

	var arrived := _travel(Vector2(_search_at.x, _search_at.y), false, delta)
	if _search_stage == 0 and not arrived:
		_look_at_body()

	if arrived or _travel_failed or _pilot.blocked:
		if _search_stage == 0 and _begin_inspect():
			return

		_search_left = search_time * 0.4 * _rng.randf_range(0.7, 1.3)


func _begin_inspect() -> bool:
	var dead := instance_from_id(_search_body) as EnemyInput
	_search_body = 0
	if dead == null or absf(dead._body.global_position.x - _body.global_position.x) > BODY_STANDOFF + 2.0:
		return false

	var id := dead.get_instance_id()
	_inspected = dead
	_cleaning = not _claimed.has(id)
	_claimed[id] = true
	_inspect_left = 1.5 + (2.0 if _cleaning else 0.0)
	return true


func _look_at_body() -> bool:
	var dead := instance_from_id(_search_body) as EnemyInput
	if dead == null and _inspect_left > 0.0:
		dead = _inspected

	if dead == null or not is_instance_valid(dead):
		return false

	has_aim = true
	aim_point = (dead.health.ragdoll.get_child(0) as Node3D).global_position + Vector3(0.0, -0.2, 0.0)
	return true


func vanish() -> void:
	var fades: Array[StandardMaterial3D] = []
	for node in _body.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue

		var override := mesh.material_override as StandardMaterial3D
		if override != null:
			mesh.material_override = _fading(override, fades)
			continue

		for i in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(i) as StandardMaterial3D
			if material != null:
				mesh.set_surface_override_material(i, _fading(material, fades))

	var tween := create_tween()
	tween.tween_method(func(amount: float) -> void:
		for material in fades:
			material.albedo_color.a = 1.0 - amount
	, 0.0, 1.0, FADE_TIME)
	tween.tween_callback(_body.queue_free)


func _fading(material: StandardMaterial3D, fades: Array[StandardMaterial3D]) -> StandardMaterial3D:
	var copy := material.duplicate() as StandardMaterial3D
	copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fades.append(copy)
	return copy


func _search_on() -> void:
	while _last_dir != 0.0 and _search_stage < 2:
		_search_stage += 1
		var ahead := _search_stage == 1
		var spot := _search_origin + Vector3((_last_dir if ahead else -_last_dir) * (SEARCH_AHEAD if ahead else SEARCH_BEHIND), 0.0, 0.0)
		if _nav.nearest(spot.x, spot.y, 1.5) >= 0:
			_search_at = spot
			return

	_mode = Mode.PATROL
	awareness = minf(awareness, SUSPECT * 0.5)
	_goal = _body.global_position
	_wait_left = _rng.randf_range(idle_time.x, idle_time.y)


func _stand_down() -> void:
	_leave_combat()
	_corpse = _target_health.ragdoll.get_child(0) as Node3D
	if absf(_corpse.global_position.x - _body.global_position.x) > CLEARED_RANGE:
		_mode = Mode.PATROL
		_goal = _body.global_position
		return

	_mode = Mode.CLEARED
	_killer = Time.get_ticks_msec() - _hit_ms < 500
	_approaching = _killer
	_cleared_left = _rng.randf_range(2.0, 4.0) * lerpf(0.8, 1.4, traits.caution) + (2.0 if _killer else 0.0)


func _cleared(delta: float) -> void:
	var at := _corpse.global_position
	var dx := at.x - _body.global_position.x
	has_aim = true
	aim_point = at + Vector3(0.0, 0.3, 0.0)

	if _approaching and absf(dx) > CORPSE_STANDOFF + 0.4:
		_travel(Vector2(at.x - signf(dx) * CORPSE_STANDOFF, at.y), false, delta)
		_approaching = not (_travel_failed or _pilot.blocked)
		return

	_approaching = false
	_stand(delta)
	_cleared_left -= delta
	if _cleared_left <= 0.0:
		_mode = Mode.PATROL
		_goal = _body.global_position
		_wait_left = _rng.randf_range(idle_time.x, idle_time.y)


func _combat(delta: float) -> void:
	var weapon := carrier.weapon
	var me := _body.global_position
	var distance := absf(_last_seen.x - me.x)

	if _plan != Plan.ENGAGE:
		_plan_age += delta
		if _plan == Plan.COVER:
			_since_seen = 0.0

	if not _visible and _since_seen > memory_time:
		_known = false
		awareness = 0.6
		_leave_combat()
		_start_search()
		return

	engaged = _visible

	_decide(delta, weapon, distance)
	match _plan:
		Plan.ENGAGE:
			_engage(delta, weapon, distance)
		Plan.COVER:
			_in_cover(delta, weapon)
		Plan.FLANK:
			_flank(delta)

	var moving := absf(move) > 0.1 or _pilot.committed
	_still_for = 0.0 if moving else _still_for + delta

	var hidden := _plan == Plan.COVER and _phase != Phase.PEEK
	var scoped := _visible and distance > scope_distance and not weapon.is_reloading() and not hidden
	scoped = scoped and _still_for > SETTLE
	_scoped_for = _scoped_for + delta if scoped else 0.0

	has_aim = (_visible or _since_seen < 1.0 or _plan == Plan.COVER) and not sprint
	aim = scoped

	if has_aim:
		var at := target.global_position if _visible or _plan == Plan.COVER else _last_seen
		var unsteady := moving or absf(target.velocity.x) > 0.3
		var braced := _crouching and not moving
		aim_point = _gunner.aim(delta, me + Vector3.UP * 1.35, at, target.crouching, unsteady, scoped, braced)

	_fire(delta, weapon, me, scoped)


func _decide(delta: float, weapon: Weapon, distance: float) -> void:
	_decide_left -= delta
	if _decide_left > 0.0:
		return

	_decide_left = _rng.randf_range(0.7, 1.4)
	if _walks_in():
		if _plan == Plan.COVER:
			_leave_plan()

		return

	var me := _body.global_position
	var there := target.global_position
	var band := _band(weapon.stats)

	var pain := _pain
	_pain *= 0.5

	if _plan == Plan.ENGAGE:
		var low := weapon.ammo <= 0 or weapon.is_reloading()
		var want := false
		if _first_contact and traits.caution >= 0.45:
			want = true
		elif pain >= 0.12 and _rng.randf() < traits.caution + 0.2:
			want = true
		elif low and _visible and _rng.randf() < traits.caution + 0.3:
			want = true
		elif _visible and traits.caution > 0.5 and _rng.randf() < (traits.caution - 0.4) * 0.25:
			want = true

		_first_contact = false
		if want and _take_cover(me, there, band):
			return

		var dug_in := not _visible and _unseen_for > 3.0 and distance < 22.0
		var teamwork := _ally_engaged()
		if _flank_cooldown <= 0.0 and (dug_in or teamwork) and _rng.randf() < traits.cunning * 0.7:
			_start_flank(me, there)

	elif _plan == Plan.COVER and _phase != Phase.GO:
		var lost := not _cover.hides(_spot, there)
		var impatient := _plan_age > 2.5 and _rng.randf() < traits.aggression * 0.5 and weapon.ammo > 0
		if lost or impatient:
			_leave_plan()
			return

		if _cover_cycles >= 2 and _flank_cooldown <= 0.0 and _ally_engaged() and _rng.randf() < traits.cunning * 0.6:
			_start_flank(me, there)


func _ally_engaged() -> bool:
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var other := node as EnemyInput
		if other != self and other.engaged and other.health.alive:
			return true

	return false


func _take_cover(me: Vector3, there: Vector3, band: Vector2) -> bool:
	var spot := _cover.find_cover(me, there, get_instance_id(), cover_search, band)
	if is_nan(spot.x):
		return false

	_plan = Plan.COVER
	_phase = Phase.GO
	_spot = spot
	_plan_age = 0.0
	_settle_left = 1.0
	_cover_cycles = 0
	_pilot.set_route(PackedVector3Array())
	EnemyCover.claim(get_instance_id(), spot)
	return true


func _start_flank(me: Vector3, there: Vector3) -> void:
	var spot := _cover.find_flank(me, there, get_instance_id(), flank_search, flank_limit)
	_flank_cooldown = 12.0
	if is_nan(spot.x):
		return

	_plan = Plan.FLANK
	_spot = spot
	_plan_age = 0.0
	_pilot.set_route(PackedVector3Array())
	EnemyCover.claim(get_instance_id(), spot)


func _leave_plan() -> void:
	EnemyCover.release(get_instance_id())
	_plan = Plan.ENGAGE
	_tactic_left = 0.0
	_pilot.set_route(PackedVector3Array())


func _in_cover(delta: float, weapon: Weapon) -> void:
	var me := _body.global_position

	if _phase == Phase.GO:
		var run := absf(_spot.x - me.x) > 3.0 and not _visible
		var arrived := _travel(_spot, run, delta)
		crouch = absf(_spot.x - me.x) < 1.0
		if _travel_failed or (_pilot.blocked and _route_left <= 0.0):
			_leave_plan()
			return

		if arrived:
			_settle_left -= delta
			if absf(_spot.x - me.x) > 0.12 and _settle_left > 0.0:
				move = signf(_spot.x - me.x) * 0.5
				return

			_pilot.stop()
			_phase = Phase.HIDE
			_hide_left = _hide_time()
			_check_left = 0.4

		return

	_pilot.stop()
	if _phase == Phase.HIDE:
		crouch = true
		_hide_left -= delta
		var loaded := weapon.ammo > 0 and not weapon.is_reloading()
		if _hide_left <= 0.0 and loaded:
			_phase = Phase.PEEK
			_peek_left = _rng.randf_range(1.2, 2.6)
			_peek_rounds = _gunner.rounds

		return

	_peek_left -= delta
	var shot := _gunner.rounds > _peek_rounds
	var done := (shot and _gunner.firing_done()) or _peek_left <= 0.0 or _hurt_left > 0.0 or weapon.ammo <= 0
	if done:
		_phase = Phase.HIDE
		_hide_left = _hide_time()
		_cover_cycles += 1
		if _hurt_left > 0.0 and traits.composure < 0.5:
			_hide_left += 0.6


func _hide_time() -> float:
	return lerpf(0.7, 2.8, traits.patience) * _rng.randf_range(0.7, 1.4) * lerpf(1.2, 0.7, traits.aggression)


func _flank(delta: float) -> void:
	var run := absf(_spot.x - _body.global_position.x) > 4.0
	var arrived := _travel(_spot, run, delta, true)
	if arrived:
		_plan = Plan.ENGAGE
		_tactic = Tactic.HOLD
		_tactic_left = _rng.randf_range(1.5, 3.0)
		_pilot.set_route(PackedVector3Array())
		_pain = 0.0
		return

	if _travel_failed or _plan_age > 25.0 or (_pilot.blocked and _route_left <= 0.0):
		_leave_plan()


func _engage(delta: float, weapon: Weapon, distance: float) -> void:
	var band := _band(weapon.stats)
	var toward := signf(_last_seen.x - _body.global_position.x)

	if _walks_in() and _tactic != Tactic.ADVANCE:
		_tactic = Tactic.ADVANCE
		_tactic_left = 0.5

	_tactic_left -= delta
	if _tactic_left <= 0.0 or (_pilot.blocked and _tactic != Tactic.HOLD):
		_pick_tactic(distance, band, weapon)

	var run := distance > maxf(
		band.y * lerpf(2.0, 1.15, traits.aggression),
		_lane(band) + 1.0 + 3.0 * traits.rush,
	)
	match _tactic:
		Tactic.ADVANCE:
			if not _visible:
				_chase(delta, run)
			elif _walks_in() and _side_full and distance > CLOSE_ENOUGH:
				_stand(delta)
			elif distance <= _lane(band) and (not _walks_in() or distance < CLOSE_ENOUGH):
				_stand(delta, toward if distance < band.x * 0.9 else 0.0)
			else:
				_pilot.walk(toward, run, delta)
		Tactic.RETREAT:
			_pilot.walk(-toward, false, delta, false)
		Tactic.STRAFE:
			_pilot.walk(_strafe, false, delta, false)
		Tactic.HOLD:
			_stand(delta, toward if distance < band.x * 0.9 else 0.0)
			crouch = _holds_low(weapon, distance, band)

	if absf(move) > 0.1 and not _pilot.committed:
		var ahead := _follow[1 if move > 0.0 else 0]
		if ahead < SPACING:
			move *= clampf((ahead - 0.3) / (SPACING - 0.3), 0.2, 1.0)

	if weapon.is_reloading() and _visible and distance < band.y and traits.caution > 0.35:
		crouch = true
	elif _hurt_left > 0.0 and traits.composure < 0.5:
		crouch = true

	if not _visible and _pilot.blocked:
		_stalled += delta
		if _stalled > 2.5:
			_stalled = 0.0
			_known = false
			awareness = 0.6
			_start_search()
	else:
		_stalled = 0.0


func _holds_low(weapon: Weapon, distance: float, band: Vector2) -> bool:
	return _visible and traits.patience > 0.6 and distance > band.x * 1.5 and weapon.stats.manual_cycle


func _chase(delta: float, run: bool) -> void:
	_travel(Vector2(_last_seen.x, _last_seen.y), run, delta)
	if _travel_failed:
		_pilot.walk(signf(_last_seen.x - _body.global_position.x), run, delta)


func _stand(delta: float, not_toward := 0.0) -> void:
	if _spread == 0.0 or _spread == not_toward or absf(_body.velocity.x) > 0.5:
		_pilot.stop()
		return

	_pilot.walk(_spread, false, delta, false)
	if not _pilot.committed:
		move *= 0.5


func _look_around(delta: float) -> void:
	_around_left -= delta
	if _around_left > 0.0:
		return

	_around_left = _rng.randf_range(0.1, 0.2)
	var me := _body.global_position
	var my_id := get_instance_id()
	var push := 0.0
	var room := 0.0
	var on_side := 0
	_follow = Vector2(INF, INF)
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var other := node as EnemyInput
		if other == self or not other.health.alive:
			continue

		if other._on_screen and other._laser == null and signf(other._body.global_position.x - target.global_position.x) == signf(me.x - target.global_position.x):
			on_side += 1

		var there := other._body.global_position
		if absf(there.y - me.y) > 1.2:
			continue

		var gap := there.x - me.x
		if absf(gap) < 0.05:
			gap = 0.05 if my_id > node.get_instance_id() else -0.05

		if absf(gap) < SPACING:
			push -= signf(gap)

		if absf(gap) < ROOM_RADIUS:
			room -= signf(gap) * (ROOM_RADIUS - absf(gap))

		var walking := other._body.velocity.x
		if absf(walking) > 0.2 and signf(walking) == signf(gap):
			var side := 1 if gap > 0.0 else 0
			_follow[side] = minf(_follow[side], absf(gap))

	_spread = signf(push)
	_room = signf(room)
	_side_full = on_side >= SIDE_LIMIT


func _pick_tactic(distance: float, band: Vector2, weapon: Weapon) -> void:
	var roll := _rng.randf()
	if not _visible:
		_tactic = Tactic.ADVANCE
		_tactic_left = 0.5
		return

	if distance > _lane(band) and _rng.randf() < traits.rush:
		_tactic = Tactic.ADVANCE
		_tactic_left = _rng.randf_range(1.2, 2.5)
		return

	if weapon.is_reloading() and distance < band.y:
		_tactic = Tactic.RETREAT if roll < 0.4 + traits.caution * 0.4 else Tactic.HOLD
		_tactic_left = _rng.randf_range(0.8, 1.8)
		return

	var press := 0.3 + traits.aggression * 0.5
	var fall_back := 0.25 + traits.caution * 0.5
	if distance > band.y:
		_tactic = Tactic.ADVANCE if roll < press else (Tactic.STRAFE if roll < press + 0.18 else Tactic.HOLD)
	elif distance < band.x:
		_tactic = Tactic.RETREAT if roll < fall_back else (Tactic.STRAFE if roll < fall_back + 0.22 else Tactic.HOLD)
	else:
		var hold := 0.2 + traits.patience * 0.4
		if roll < hold:
			_tactic = Tactic.HOLD
		elif roll < hold + 0.3 + (1.0 - traits.patience) * 0.2:
			_tactic = Tactic.STRAFE
		elif roll < hold + 0.55 + traits.aggression * 0.2:
			_tactic = Tactic.ADVANCE
		else:
			_tactic = Tactic.RETREAT

	var lane := _lane(band)
	if _tactic == Tactic.ADVANCE and distance <= lane:
		_tactic = Tactic.STRAFE
	elif _tactic == Tactic.RETREAT and distance >= lane and distance <= band.y:
		_tactic = Tactic.STRAFE

	if _tactic == Tactic.STRAFE:
		if _room != 0.0 and _rng.randf() < 0.8:
			_strafe = _room
		else:
			_strafe = 1.0 if _rng.randf() < 0.5 + traits.strafe_bias * 0.3 else -1.0

	match _tactic:
		Tactic.HOLD:
			_tactic_left = _rng.randf_range(0.6, 2.2) * lerpf(0.8, 1.5, traits.patience)
		Tactic.STRAFE:
			_tactic_left = _rng.randf_range(0.5, 1.4)
		_:
			_tactic_left = _rng.randf_range(0.8, 2.0)


func _lane(band: Vector2) -> float:
	return lerpf(band.x * 1.1, band.y * 0.95, traits.lane)


func _band(stats: WeaponStats) -> Vector2:
	var band := pistol_range
	if stats.pellets > 1:
		band = shotgun_range
	elif stats.manual_cycle:
		band = sniper_range
	elif stats.automatic:
		band = rifle_range

	band *= traits.range_scale
	if _fair_on and _laser == null:
		band.y = minf(band.y, _view_reach)
		band.x = minf(band.x, _view_reach * 0.6)

	return band


func _fire(delta: float, weapon: Weapon, me: Vector3, scoped: bool) -> void:
	if not _hidden or _laser != null:
		_react_left = maxf(_react_left - delta, 0.0)

	if _laser != null:
		_paint(delta, weapon, scoped)

	_shot_left -= delta
	if _shot_left <= 0.0 and weapon.holder.gun.is_inside_tree():
		_shot_left = _rng.randf_range(0.03, 0.06)
		var ray := weapon.bullet_ray()
		var from := ray[0]
		var along := ray[1]
		var reach := absf(target.global_position.x - me.x)
		_shot = _senses.shot(from, along, reach, _target_health, weapon.friendly_fire)

	var gun_up := not scoped or _scoped_for > weapon.stats.ads_time + 0.05
	var steady := _gunner.settled > 0.15
	var may_fire := _visible and _react_left <= 0.0 and _hurt_left <= 0.0 and gun_up and steady
	may_fire = may_fire and _shot == EnemySenses.Shot.CLEAR and not sprint
	may_fire = may_fire and (not _hidden or _paint_for >= PAINT_TIME)
	if _plan == Plan.COVER:
		may_fire = may_fire and _phase == Phase.PEEK

	if _visible and _shot == EnemySenses.Shot.ALLY and _plan == Plan.ENGAGE and _tactic == Tactic.HOLD:
		_tactic = Tactic.STRAFE
		_tactic_left = _rng.randf_range(0.5, 1.2)

	fire = _gunner.trigger(delta, may_fire, weapon)


func _paint(delta: float, weapon: Weapon, scoped: bool) -> void:
	_painting = _visible and scoped and not weapon.is_reloading() and weapon.holder.gun.is_inside_tree()
	if not _painting:
		return

	_paint_for += delta
	var ray := weapon.bullet_ray()
	var length := _senses.beam(ray[0], ray[1], 80.0)
	_laser.show_beam(ray[0], ray[1], length, clampf(_paint_for / PAINT_TIME, 0.0, 1.0))


func _reload(delta: float) -> void:
	_reload_left -= delta
	if _reload_left > 0.0:
		return

	var weapon := carrier.weapon
	var quiet := not _visible and _mode != Mode.COMBAT
	var hiding := _mode == Mode.COMBAT and _plan == Plan.COVER and _phase == Phase.HIDE
	var lull := _mode == Mode.COMBAT and not fire
	if hiding and weapon.ammo < weapon.stats.magazine_size:
		lull = true
		quiet = _rng.randf() < 0.6 or weapon.ammo * 2 <= weapon.stats.magazine_size

	if _gunner.wants_reload(weapon, quiet, lull):
		reload = true
		_reload_left = 0.5
		_gunner.reloaded()
