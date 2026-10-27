class_name AmmoHud
extends CanvasLayer

const INK := Color(0.93, 0.93, 0.9)
const DIM := Color(0.93, 0.93, 0.9, 0.5)
const PLATE := Color(0.035, 0.04, 0.045, 0.62)
const BLOOD := Color(0.8, 0.16, 0.14)
const AMBER := Color(0.92, 0.62, 0.2)
const NOTICE_TIME := 2.2

@export var margin := 24.0
@export var design_height := 1080.0

var loot: PlayerLoot

var _canvas: Control
var _box := StyleBoxFlat.new()
var _notices: Array[Array] = []


class Canvas extends Control:
	var hud: AmmoHud


	func _draw() -> void:
		hud.paint(self)


func _ready() -> void:
	_box.bg_color = PLATE
	_box.set_corner_radius_all(7)

	var canvas := Canvas.new()
	canvas.hud = self
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	_canvas = canvas
	loot.collected.connect(_on_collected)
	loot.tree_exited.connect(queue_free)


func _process(delta: float) -> void:
	for notice in _notices:
		notice[2] = float(notice[2]) - delta

	_notices = _notices.filter(func(n: Array) -> bool: return float(n[2]) > 0.0)
	_canvas.queue_redraw()


func paint(c: Control) -> void:
	var k := c.size.y / design_height
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	var view := c.size / k
	var weapon: Weapon = loot._carrier.weapon
	var pouch := weapon.pouch
	var font := ThemeDB.fallback_font
	var area := Rect2(margin + 312.0, view.y - margin - 98.0, 190.0, 98.0)
	c.draw_style_box(_box, area)

	var type := weapon.stats.ammo_type
	c.draw_string(font, area.position + Vector2(16.0, 26.0), AmmoPouch.NAMES[type], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, DIM)

	var loaded := weapon.ammo
	var limited := pouch != null and not weapon.infinite_ammo
	var reserve := pouch.count(type) if limited else 0
	var tint := INK
	if loaded <= 0:
		tint = BLOOD
	elif loaded <= maxi(weapon.stats.magazine_size / 4, 1):
		tint = AMBER

	var big := str(loaded)
	c.draw_string(font, area.position + Vector2(16.0, 70.0), big, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 38, tint)
	var width := font.get_string_size(big, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 38).x

	if not limited:
		c.draw_string(font, area.position + Vector2(24.0 + width, 70.0), "∞", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, DIM)
	else:
		var low := reserve <= weapon.stats.magazine_size
		c.draw_string(
			font,
			area.position + Vector2(24.0 + width, 70.0),
			"/ %d" % reserve,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			24,
			(BLOOD if reserve == 0 else AMBER) if low else DIM,
		)

	var y := area.position.y - 10.0
	for notice in _notices:
		var fade := clampf(float(notice[2]) / 0.6, 0.0, 1.0)
		c.draw_string(
			font,
			Vector2(area.position.x, y),
			"+%d %s" % [notice[1], AmmoPouch.NAMES[notice[0]]],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			15,
			Color(INK, fade),
		)
		y -= 20.0


func _on_collected(type: StringName, amount: int) -> void:
	for notice in _notices:
		if notice[0] == type and float(notice[2]) > NOTICE_TIME - 0.5:
			notice[1] = int(notice[1]) + amount
			notice[2] = NOTICE_TIME
			return

	_notices.append([type, amount, NOTICE_TIME])
