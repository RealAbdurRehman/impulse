class_name Reticle
extends CanvasLayer

const INK := Color(0.93, 0.93, 0.9)
const HOT := Color(0.92, 0.22, 0.18)
const AMBER := Color(0.92, 0.62, 0.2)
const SHADOW := Color(0.0, 0.0, 0.0, 0.42)

enum Mark { NONE, HIT, HEAD, KILL, KILL_HEAD }

const PROBES := [
	Vector3(0.0, 0.0, 0.0),
	Vector3(1.0, 0.0, 0.0),
	Vector3(-1.0, 0.0, 0.0),
	Vector3(0.0, 1.0, 0.0),
	Vector3(0.0, -1.0, 0.0),
	Vector3(0.0, 0.0, 0.8),
	Vector3(0.0, 0.0, -0.8),
]


class Canvas extends Control:
	var reticle: Reticle

	func _draw() -> void:
		reticle.paint(self)


@export var target: CharacterMovement
@export var design_height := 1080.0
@export var hide_system_cursor := true

@export_group("Cursor")
@export_range(0.0, 1.0) var rest_alpha := 0.6
@export var cursor_radius := 3.2
@export var ring_radius := 12.0
@export var ring_show_time := 1.6
@export_range(0.0, 1.0) var low_ammo := 0.3

@export_group("Barrel")
@export var min_gap := 5.5
@export var tick_length := 5.5
@export var kick_gap := 4.0
@export var min_distance := 0.6
@export var target_tolerance := 0.15

@export_group("Markers")
@export var hit_time := 0.24
@export var kill_time := 0.6

var _canvas: Canvas
var _carrier: WeaponCarrier
var _healing: PlayerHealing
var _weapon: Weapon
var _dead := false

var _armed := false
var _was_armed := false
var _bullet := Vector2.ZERO
var _bullet_before := Vector2.ZERO
var _spread := 0.0
var _looking_at_enemy := false

var _alpha := 0.0
var _shown_spread := 0.0
var _hostile := 0.0
var _emphasis := 0.0
var _visible := 0.0
var _pulse := 0.0
var _flash := 0.0
var _ring_time := 0.0
var _reload_elapsed := 0.0

var _mark := Mark.NONE
var _mark_age := 0.0
var _died := { }


func _init() -> void:
	process_physics_priority = 20


func _ready() -> void:
	layer = 10

	_canvas = Canvas.new()
	_canvas.reticle = self
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)

	_carrier = target.get_node("WeaponCarrier") as WeaponCarrier
	_healing = target.get_node("PlayerHealing") as PlayerHealing
	target.health.died.connect(_on_player_died)

	_watch(get_tree().root)
	get_tree().node_added.connect(_watch_new)

	if hide_system_cursor:
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN


func _exit_tree() -> void:
	if hide_system_cursor:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _watch(node: Node) -> void:
	_watch_new(node)
	for child in node.get_children():
		_watch(child)


func _watch_new(node: Node) -> void:
	var health := node as Health
	if health != null and health != target.health:
		health.died.connect(_on_died.bind(health))


func _on_died(health: Health) -> void:
	_died[health] = Engine.get_physics_frames()


func _on_player_died() -> void:
	_dead = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _bind(weapon: Weapon) -> void:
	_weapon = weapon
	weapon.fired.connect(_on_fired)
	weapon.dry_fired.connect(_on_dry_fired)
	weapon.bullet_traced.connect(_on_traced)
	weapon.reload_started.connect(_on_reload_started)
	weapon.ammo_changed.connect(_on_ammo_changed)


func _on_fired(_muzzle: Transform3D) -> void:
	_pulse = 1.0
	_ring_time = ring_show_time


func _on_dry_fired() -> void:
	_flash = 1.0
	_ring_time = ring_show_time


func _on_reload_started() -> void:
	_reload_elapsed = 0.0
	_ring_time = ring_show_time


func _on_ammo_changed(_current: int, _capacity: int) -> void:
	_ring_time = ring_show_time


func _on_traced(_from: Vector3, _to: Vector3, hit: Dictionary) -> void:
	if hit.is_empty():
		return

	var health := Health.of(hit.collider)
	if health == null or health == target.health:
		return

	var killed: bool = int(_died.get(health, -9)) >= Engine.get_physics_frames() - 1
	if not health.alive and not killed:
		return

	var bone := Hitboxes.bone_of(hit.collider)
	var head := bone != null and String(bone.bone_name).ends_with("Head")

	var kind := Mark.HEAD if head else Mark.HIT
	if killed:
		kind = Mark.KILL_HEAD if head else Mark.KILL

	if _mark_age > 0.12 or kind >= _mark:
		_mark = kind
		_mark_age = 0.0


func _physics_process(delta: float) -> void:
	if _carrier.weapon != _weapon:
		_bind(_carrier.weapon)

	_armed = false
	if _dead or not is_instance_valid(_weapon) or not target.input.has_aim:
		return

	var holder := _weapon.holder
	if holder.muzzle == null or not holder.gun.is_inside_tree():
		return

	_armed = true
	if _weapon.is_reloading():
		_reload_elapsed += delta

	var ray := _weapon.bullet_ray()
	var origin := ray[0]
	var forward := ray[1]
	var aim := target.aim_point
	var reach := clampf(
		Vector2(aim.x - origin.x, aim.y - origin.y).length(),
		min_distance,
		_weapon.stats.max_range,
	)

	var camera := get_viewport().get_camera_3d()
	var point := origin + forward * reach
	var at := camera.unproject_position(point)
	var per_meter := absf(camera.unproject_position(point + Vector3.UP).y - at.y)

	var spread_meters := tan(_weapon.spread_cone()) * reach
	_bullet_before = _bullet if _was_armed else at
	_bullet = at
	_spread = spread_meters * per_meter

	var on_screen := get_viewport().get_visible_rect().grow(-6.0).has_point(at)
	_looking_at_enemy = on_screen and _over_enemy(point, clampf(target_tolerance + spread_meters * 0.5, 0.1, 0.45))


func _over_enemy(point: Vector3, radius: float) -> bool:
	var query := PhysicsPointQueryParameters3D.new()
	query.collision_mask = _weapon.stats.hit_mask | Hitboxes.LAYER
	query.collide_with_areas = true

	var space := target.get_world_3d().direct_space_state
	for probe in PROBES:
		query.position = point + probe * radius
		for found in space.intersect_point(query, 8):
			var health := Health.of(found.collider)
			if health != null and health != target.health and health.alive and not _is_friend(health):
				return true

	return false


func _is_friend(health: Health) -> bool:
	return health.team != &"" and health.team == target.health.team


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.05)

	var want := 0.0
	if _armed:
		want = 0.4 if _healing.is_applying() else 1.0

	_alpha = lerpf(_alpha, want, 1.0 - exp(-12.0 * real))
	_shown_spread = lerpf(_shown_spread, _spread, 1.0 - exp(-26.0 * real))
	_hostile = lerpf(_hostile, 1.0 if _looking_at_enemy else 0.0, 1.0 - exp(-18.0 * real))
	_pulse = maxf(_pulse - 9.0 * real, 0.0)
	_flash = maxf(_flash - 5.0 * real, 0.0)
	_ring_time = maxf(_ring_time - real, 0.0)
	_mark_age += real
	_was_armed = _armed

	var lively := maxf(maxf(_pulse, clampf(_ring_time / 0.5, 0.0, 1.0)), _hostile)
	if is_instance_valid(_weapon):
		lively = maxf(lively, _weapon.character.aim_amount)

	_emphasis = lerpf(_emphasis, lively, 1.0 - exp(-10.0 * real))
	_visible = _alpha * lerpf(rest_alpha, 1.0, _emphasis)

	_canvas.queue_redraw()


func paint(c: Control) -> void:
	if _alpha < 0.01 or not is_instance_valid(_weapon):
		return

	var k := c.size.y / design_height
	var mouse := get_viewport().get_mouse_position()
	var bullet := _bullet_before.lerp(_bullet, Engine.get_physics_interpolation_fraction())
	var tone := INK.lerp(HOT, _hostile)

	if bullet.distance_to(mouse) > (cursor_radius + 6.0) * k:
		_connector(c, mouse, bullet, k)

	_paint_ring(c, mouse, k)
	_paint_cursor(c, mouse, k)
	_paint_barrel(c, bullet, k, tone)
	_paint_mark(c, bullet, k)


func _paint_cursor(c: Control, at: Vector2, k: float) -> void:
	var aim := _weapon.character.aim_amount
	_arc(c, at, lerpf(cursor_radius, cursor_radius * 0.75, aim) * k, 1.1 * k, 0.0, TAU, Color(INK, 0.9 * _visible), k)


func _connector(c: Control, from: Vector2, to: Vector2, k: float) -> void:
	var along := (to - from).normalized()
	var start := from + along * (cursor_radius + 3.0) * k
	var end := to - along * 3.0 * k
	c.draw_line(start, end, Color(INK, 0.14 * _visible), 0.9 * k, true)


func _paint_barrel(c: Control, at: Vector2, k: float, tone: Color) -> void:
	var stats := _weapon.stats
	var aim := _weapon.character.aim_amount
	var gap := minf(maxf(min_gap * k, _shown_spread) + kick_gap * k * _pulse, 240.0 * k)
	var color := Color(tone, _visible)

	if stats.pellets > 1:
		var step := TAU / 8.0
		for i in 8:
			_arc(c, at, gap, 1.4 * k, step * float(i) + 0.1, step * (float(i) + 0.62), color, k)
	else:
		var width := lerpf(1.5, 1.2, aim) * k
		var length := lerpf(tick_length, tick_length * 1.4, aim) * k
		for dir in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
			_stroke(c, at + dir * gap, at + dir * (gap + length), width, color, k)

	_dot(c, at, 1.2 * k, color, k)


func _paint_ring(c: Control, at: Vector2, k: float) -> void:
	var stats := _weapon.stats
	var radius := ring_radius * k
	var capacity := stats.magazine_size
	var fraction := float(_weapon.ammo) / float(capacity)
	var low := fraction <= low_ammo
	var reloading := _weapon.is_reloading()

	var show := clampf(_ring_time / 0.4, 0.0, 1.0)
	if low or reloading:
		show = 1.0

	if show <= 0.01:
		return

	var base := Color(INK, 0.16 * show * _alpha)
	if reloading:
		var progress := clampf(_reload_elapsed / maxf(_weapon.reload_total, 0.01), 0.0, 1.0)
		_arc(c, at, radius, 1.6 * k, 0.0, TAU, base, k)
		_arc(c, at, radius, 1.6 * k, -PI * 0.5, -PI * 0.5 + TAU * progress, Color(AMBER, 0.95 * _alpha), k)
		return

	var segments := mini(capacity, 30)
	var lit := ceili(fraction * float(segments))
	var step := TAU / float(segments)
	var color := INK
	if low:
		color = HOT.lerp(AMBER, 0.0 if _weapon.ammo <= 0 else 0.5)
		show *= 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.012)

	color = color.lerp(HOT, _flash)
	var gap_angle := minf(step * 0.32, 0.12)
	for i in segments:
		var from := -PI * 0.5 + step * float(i) + gap_angle
		var to := -PI * 0.5 + step * float(i + 1) - gap_angle
		var on := i < lit
		_arc(c, at, radius, 1.6 * k, from, to, Color(color, (0.85 if on else 0.16) * show * _alpha), k)


func _paint_mark(c: Control, at: Vector2, k: float) -> void:
	if _mark == Mark.NONE:
		return

	var killed := _mark == Mark.KILL or _mark == Mark.KILL_HEAD
	var life := kill_time if killed else hit_time
	var t := _mark_age / life
	if t >= 1.0:
		_mark = Mark.NONE
		return

	var fade := pow(1.0 - t, 1.3)
	var pop := 1.0 + 0.35 * pow(1.0 - minf(t * 4.0, 1.0), 2.0)
	var color := HOT if killed else (AMBER if _mark == Mark.HEAD else INK)

	var near := (7.0 + 4.0 * t) * k * pop
	var far := near + (6.0 if killed else 4.5) * k * pop
	for diagonal in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		var dir: Vector2 = diagonal.normalized()
		_stroke(c, at + dir * near, at + dir * far, (2.2 if killed else 1.8) * k, Color(color, fade), k)

	if _mark == Mark.KILL_HEAD:
		_arc(c, at, (8.0 + 18.0 * t) * k, 1.2 * k, 0.0, TAU, Color(AMBER, 0.7 * pow(1.0 - t, 2.0)), k)
	elif killed:
		_arc(c, at, (7.0 + 12.0 * t) * k, 1.1 * k, 0.0, TAU, Color(HOT, 0.45 * pow(1.0 - t, 2.0)), k)


func _stroke(c: Control, from: Vector2, to: Vector2, width: float, color: Color, k: float) -> void:
	c.draw_line(from, to, Color(SHADOW, SHADOW.a * color.a), width + 1.2 * k, true)
	c.draw_line(from, to, color, width, true)


func _arc(c: Control, at: Vector2, radius: float, width: float, from: float, to: float, color: Color, k: float) -> void:
	var points := maxi(int(absf(to - from) * radius / (1.5 * k)), 6)
	c.draw_arc(at, radius, from, to, points, Color(SHADOW, SHADOW.a * color.a), width + 1.2 * k, true)
	c.draw_arc(at, radius, from, to, points, color, width, true)


func _dot(c: Control, at: Vector2, radius: float, color: Color, k: float) -> void:
	c.draw_circle(at, radius + 0.6 * k, Color(SHADOW, SHADOW.a * color.a))
	c.draw_circle(at, radius, color)
