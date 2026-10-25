class_name PlayerHud
extends CanvasLayer

const INK := Color(0.93, 0.93, 0.9)
const DIM := Color(0.93, 0.93, 0.9, 0.5)
const PLATE := Color(0.035, 0.04, 0.045, 0.62)
const TRACK := Color(1.0, 1.0, 1.0, 0.1)
const BLOOD := Color(0.8, 0.16, 0.14)
const GAUZE := Color(0.93, 0.89, 0.79)
const AMBER := Color(0.92, 0.62, 0.2)

@export var health: Health
@export var healing: PlayerHealing
@export var stamina: PlayerStamina

@export var margin := 24.0
@export var design_height := 1080.0

class Canvas extends Control:
	var hud: PlayerHud

	func _draw() -> void:
		hud.paint(self)

var _canvas: Canvas
var _box := StyleBoxFlat.new()


func _ready() -> void:
	_box.bg_color = PLATE
	_box.set_corner_radius_all(7)

	_canvas = Canvas.new()
	_canvas.hud = self
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)


func _process(_delta: float) -> void:
	_canvas.queue_redraw()


func paint(c: Control) -> void:
	var k := c.size.y / design_height
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	var view := c.size / k
	_paint_vitals(c, view)


func _paint_vitals(c: Control, view: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var area := Rect2(margin, view.y - margin - 98.0, 300.0, 98.0)
	c.draw_style_box(_box, area)

	var frac := clampf(health.current / health.max_health, 0.0, 1.0)
	var bar := Rect2(area.position + Vector2(16.0, 34.0), Vector2(268.0, 10.0))
	c.draw_rect(bar, TRACK)
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), INK.lerp(BLOOD, clampf(1.0 - frac * 2.2, 0.0, 1.0)))

	_paint_stamina(c, area)

	c.draw_string(font, area.position + Vector2(16.0, 26.0), "HEALTH", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, DIM)
	c.draw_string(font, area.position + Vector2(284.0, 26.0), str(ceili(health.current)), HORIZONTAL_ALIGNMENT_RIGHT, -1.0, 15, INK)

	var bleed := healing.bleed_rate()
	if bleed > 0.02:
		var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.007)
		var tint := Color(BLOOD, pulse)
		c.draw_circle(area.position + Vector2(22.0, 76.0), 4.0, tint)
		c.draw_string(font, area.position + Vector2(34.0, 81.0), "BLEEDING  -%.1f/s" % bleed, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, tint)

	var x := area.end.x - 18.0
	for i in healing.bandages:
		_paint_roll(c, Vector2(x, area.position.y + 76.0))
		x -= 22.0

	if healing.bandages > 0 and healing.open_wounds() > 0 and not healing.is_applying():
		c.draw_string(font, Vector2(x - 6.0, area.position.y + 81.0), "F", HORIZONTAL_ALIGNMENT_RIGHT, -1.0, 13, GAUZE)


func _paint_stamina(c: Control, area: Rect2) -> void:
	var bar := Rect2(area.position + Vector2(16.0, 52.0), Vector2(268.0, 5.0))
	c.draw_rect(bar, TRACK)

	var tint := INK
	if stamina.exhausted:
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.012)
		tint = Color(AMBER, pulse)
		var mark := bar.position.x + bar.size.x * stamina.recover_at
		c.draw_rect(Rect2(mark - 1.0, bar.position.y - 3.0, 2.0, bar.size.y + 6.0), Color(AMBER, 0.8))
	else:
		tint = Color(INK, lerpf(0.9, 0.35, smoothstep(0.6, 1.0, stamina.fraction())))

	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * stamina.fraction(), bar.size.y)), tint)


func _paint_roll(c: Control, at: Vector2) -> void:
	c.draw_circle(at, 8.0, GAUZE)
	c.draw_circle(at, 5.0, Color(0.7, 0.66, 0.56))
	c.draw_circle(at, 2.2, GAUZE)
