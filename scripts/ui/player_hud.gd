class_name PlayerHud
extends CanvasLayer

const INK := Color(0.93, 0.93, 0.9)
const BLOOD := Color(0.86, 0.2, 0.17)
const GAUZE := Color(0.93, 0.89, 0.79)
const AMBER := Color(0.92, 0.62, 0.2)
const SHADOW := Color(0.0, 0.0, 0.0, 0.42)
const ROLLS_SHOWN := 5

@export var health: Health
@export var healing: PlayerHealing
@export var stamina: PlayerStamina

@export var margin := 28.0
@export var design_height := 1080.0
@export var bar_width := 210.0

@export_group("Visibility")
@export var linger := 2.4
@export var intro_time := 2.0
@export var squad_time := 2.2
@export_range(0.0, 1.0) var low_health := 0.35


class Canvas extends Control:
	var hud: PlayerHud


	func _draw() -> void:
		hud.paint(self)


var _canvas: Canvas
var _fill := StyleBoxFlat.new()
var _k := 1.0

var _vitals := 0.0
var _stamina := 0.0
var _aid := 0.0
var _squad := 0.0

var _vitals_left := 0.0
var _stamina_left := 0.0
var _aid_left := 0.0
var _squad_left := 0.0

var _last_health := 0.0
var _last_bandages := 0
var _following := false
var _shown := 0.0
var _ghost := 1.0
var _ghost_hold := 0.0
var _gain := 0.0
var _pop := 0.0


func _ready() -> void:
	_fill.set_corner_radius_all(64)

	_canvas = Canvas.new()
	_canvas.hud = self
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)

	_last_health = health.current
	_shown = health.current
	_ghost = _fraction()
	_last_bandages = healing.bandages
	_following = Targeter.following
	_vitals_left = intro_time


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.05)
	var bleed := healing.bleed_rate()
	var applying := healing.is_applying()
	var frac := _fraction()

	var change := health.current - _last_health
	_last_health = health.current
	if absf(change) > 0.01:
		_vitals_left = linger

	if change < -0.01:
		_ghost_hold = 0.5
	elif change > 0.01:
		_gain = 1.0

	if healing.bandages != _last_bandages:
		_aid_left = linger
		_pop = 1.0 if healing.bandages > _last_bandages else 0.0
		_last_bandages = healing.bandages

	if Targeter.following != _following:
		_following = Targeter.following
		_squad_left = squad_time

	if stamina.fraction() < 0.995 or stamina.exhausted:
		_stamina_left = 0.7

	_vitals_left = maxf(_vitals_left - real, 0.0)
	_stamina_left = maxf(_stamina_left - real, 0.0)
	_aid_left = maxf(_aid_left - real, 0.0)
	_squad_left = maxf(_squad_left - real, 0.0)
	_ghost_hold = maxf(_ghost_hold - real, 0.0)
	_gain = maxf(_gain - 2.0 * real, 0.0)
	_pop = maxf(_pop - 3.0 * real, 0.0)

	_shown = move_toward(
		_shown,
		health.current,
		real * maxf(30.0, absf(health.current - _shown) * 4.0),
	)
	if _ghost < frac:
		_ghost = frac
	elif _ghost_hold <= 0.0:
		_ghost = move_toward(_ghost, frac, 0.6 * real)

	var on := health.alive
	_vitals = _fade(
		_vitals,
		on and (frac <= low_health or bleed > 0.02 or applying or _vitals_left > 0.0),
		real,
	)
	_stamina = _fade(_stamina, on and _stamina_left > 0.0, real)
	_aid = _fade(_aid, on and (bleed > 0.02 or applying or _aid_left > 0.0), real)
	_squad = _fade(_squad, on and _squad_left > 0.0, real)

	_canvas.visible = maxf(maxf(_vitals, _stamina), maxf(_aid, _squad)) > 0.01
	if _canvas.visible:
		_canvas.queue_redraw()


func paint(c: Control) -> void:
	_k = c.size.y / design_height
	var origin := Vector2(margin, c.size.y / _k - margin)
	_paint_stamina(c, origin)
	_paint_health(c, origin)
	_paint_aid(c, origin)
	_paint_squad(c, origin)


func _fraction() -> float:
	return clampf(health.current / health.max_health, 0.0, 1.0)


func _fade(value: float, on: bool, real: float) -> float:
	var want := 1.0 if on else 0.0
	return lerpf(value, want, 1.0 - exp(-(14.0 if want > value else 3.5) * real))


func _paint_stamina(c: Control, o: Vector2) -> void:
	if _stamina <= 0.01:
		return

	var bar := Rect2(o + Vector2(0.0, -4.0 + (1.0 - _stamina) * 5.0), Vector2(bar_width, 3.0))
	_pill(c, bar.grow(1.0), Color(SHADOW, 0.5 * _stamina))
	_pill(c, bar, Color(INK, 0.16 * _stamina))

	var tone := Color(INK, 0.85 * _stamina)
	if stamina.exhausted:
		tone = Color(AMBER, (0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.012)) * _stamina)
		var mark := bar.position.x + bar.size.x * stamina.recover_at
		_pill(
			c,
			Rect2(mark - 0.75, bar.position.y - 3.0, 1.5, bar.size.y + 6.0),
			Color(AMBER, 0.8 * _stamina),
		)

	_pill(
		c,
		Rect2(bar.position, Vector2(maxf(bar.size.x * stamina.fraction(), bar.size.y), bar.size.y)),
		tone,
	)


func _paint_health(c: Control, o: Vector2) -> void:
	if _vitals <= 0.01:
		return

	var lift := (1.0 - _vitals) * 6.0
	var frac := _fraction()
	var bar := Rect2(o + Vector2(0.0, -14.0 + lift), Vector2(bar_width, 4.0))
	_pill(c, bar.grow(1.0), Color(SHADOW, 0.5 * _vitals))
	_pill(c, bar, Color(INK, 0.16 * _vitals))

	var tone := INK.lerp(BLOOD, clampf(1.0 - frac * 2.2, 0.0, 1.0)).lerp(GAUZE, _gain * 0.6)
	if _ghost > frac:
		_pill(
			c,
			Rect2(bar.position, Vector2(bar.size.x * _ghost, bar.size.y)),
			Color(BLOOD, 0.75 * _vitals),
		)

	if frac > 0.0:
		_pill(
			c,
			Rect2(bar.position, Vector2(maxf(bar.size.x * frac, bar.size.y), bar.size.y)),
			Color(tone, 0.95 * _vitals),
		)

	var number := str(ceili(_shown))
	var base := o + Vector2(0.0, -21.0 + lift)
	_text(c, base, number, 18, Color(tone, 0.9 * _vitals))

	if healing.bleed_rate() > 0.02:
		var beat := (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)) * _vitals
		_dot(
			c,
			Vector2(base.x + _width(number, 18) + 9.0, base.y - 5.5),
			2.6,
			Color(BLOOD, lerpf(0.35, 1.0, beat)),
		)


func _paint_aid(c: Control, o: Vector2) -> void:
	if _aid <= 0.01:
		return

	var y := o.y - 64.0 + (1.0 - _aid) * 6.0
	var count := healing.bandages
	var tone := Color(GAUZE, _aid)
	var x := o.x
	_pill(c, Rect2(x, y - 1.2, 9.0, 2.4), tone)
	_pill(c, Rect2(x + 3.3, y - 4.5, 2.4, 9.0), tone)
	x += 20.0

	if count == 0:
		_ring(c, Vector2(x + 3.0, y), 3.0, 1.4, Color(INK, 0.35 * _aid))
		x += 12.0
	elif count <= ROLLS_SHOWN:
		for i in count:
			var last := i == count - 1
			_dot(c, Vector2(x + 3.0, y), 3.2 * (1.0 + 0.5 * _pop if last else 1.0), tone)
			x += 12.0
	else:
		var label := "×%d" % count
		_dot(c, Vector2(x + 3.0, y), 3.2, tone)
		_text(c, Vector2(x + 12.0, y + 5.0), label, 15, tone)
		x += 14.0 + _width(label, 15)

	var applying := healing.is_applying()
	if applying or (count > 0 and healing.bleed_rate() > 0.02):
		var beat := 1.0 if applying else 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.008)
		var progress := clampf(healing.progress, 0.0, 1.0) if applying else 0.0
		_cap(c, Vector2(x + 14.0, y), "F", Color(GAUZE, _aid * beat), progress)


func _paint_squad(c: Control, o: Vector2) -> void:
	if _squad <= 0.01:
		return

	var at := Vector2(o.x - (1.0 - _squad) * 8.0, o.y - 94.0)
	var ink := Color(INK, _squad)
	_cap(c, at + Vector2(10.0, 0.0), "V", ink, 0.0)

	var icon := at + Vector2(34.0, 0.0)
	if _following:
		for i in 2:
			var s := icon + Vector2(i * 6.5, 0.0)
			_stroke(
				c,
				PackedVector2Array(
					[s + Vector2(0.0, -4.5), s + Vector2(4.5, 0.0), s + Vector2(0.0, 4.5)]
				),
				1.9,
				ink,
			)
	else:
		_pill(c, Rect2(icon + Vector2(0.5, -4.5), Vector2(2.8, 9.0)), ink)
		_pill(c, Rect2(icon + Vector2(6.5, -4.5), Vector2(2.8, 9.0)), ink)

	var from := at + Vector2(56.0, 5.0)
	_text(c, from, "ALLIES", 12, Color(INK, 0.55 * _squad))
	_text(
		c,
		from + Vector2(_width("ALLIES", 12) + 8.0, 1.0),
		"FOLLOW" if _following else "HOLD",
		15,
		ink,
	)


func _cap(c: Control, at: Vector2, letter: String, color: Color, progress: float) -> void:
	_ring(c, at, 10.0, 1.6, Color(color, color.a * 0.32))
	if progress > 0.0:
		var from := -PI * 0.5
		var to := from + TAU * progress
		_arc(c, at, 10.0, from, to, 2.4, color)
		_dot(c, at + Vector2.from_angle(from) * 10.0, 1.2, color)
		_dot(c, at + Vector2.from_angle(to) * 10.0, 1.2, color)

	_text(c, at + Vector2(-_width(letter, 12) * 0.5, 4.3), letter, 12, color)


func _pill(c: Control, rect: Rect2, color: Color) -> void:
	_fill.bg_color = color
	c.draw_style_box(_fill, Rect2(rect.position * _k, rect.size * _k))


func _dot(c: Control, at: Vector2, radius: float, color: Color) -> void:
	c.draw_circle(at * _k, radius * _k, color, true, -1.0, true)


func _ring(c: Control, at: Vector2, radius: float, width: float, color: Color) -> void:
	c.draw_arc(at * _k, radius * _k, 0.0, TAU, 64, color, width * _k, true)


func _arc(
	c: Control,
	at: Vector2,
	radius: float,
	from: float,
	to: float,
	width: float,
	color: Color,
) -> void:
	c.draw_arc(at * _k, radius * _k, from, to, 64, color, width * _k, true)


func _stroke(c: Control, points: PackedVector2Array, width: float, color: Color) -> void:
	var scaled := PackedVector2Array()
	for point in points:
		scaled.append(point * _k)

	c.draw_polyline(scaled, color, width * _k, true)


func _text(c: Control, at: Vector2, text: String, size: float, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var px := maxi(roundi(size * _k), 8)
	c.draw_string(
		font,
		at * _k + Vector2.ONE * _k,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		px,
		Color(SHADOW, 0.6 * color.a),
	)
	c.draw_string(font, at * _k, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, color)


func _width(text: String, size: float) -> float:
	var px := maxi(roundi(size * _k), 8)
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x / _k
