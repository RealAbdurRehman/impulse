class_name ScreenFx
extends CanvasLayer

const OVERLAY := preload("res://scripts/camera/shaders/screen_overlay.gdshader")
const GRADE := preload("res://scripts/camera/shaders/screen_grade.gdshader")
const SLOTS := 4


class Uniforms:
	var material := ShaderMaterial.new()
	var _sent := { }

	func _init(shader: Shader) -> void:
		material.shader = shader

	func send(key: StringName, value: Variant) -> void:
		var last: Variant = _sent.get(key)
		if last != null:
			if typeof(value) == TYPE_FLOAT and absf(value - last) < 0.0002:
				return

			if typeof(value) == TYPE_VECTOR2 and value.distance_to(last) < 0.0002:
				return

		_sent[key] = value
		material.set_shader_parameter(key, value)


@export var base_vignette := 0.12
@export var smoothing := 30.0

@export_group("Damage streaks")
@export var streak_time := 1.7
@export var strike_decay := 5.0
@export var streak_merge := 0.14

var vignette := 0.0
var aberration := 0.0
var desaturate := 0.0
var fade := 1.0
var blood := 0.0
var focus := 0.0
var haze := 0.0
var scope := 0.0
var scope_dir := Vector2.RIGHT
var scope_anchor := Vector2(0.5, 0.5)

var _overlay := Uniforms.new(OVERLAY)
var _grade := Uniforms.new(GRADE)
var _grade_rect: ColorRect

var _vignette := 0.0
var _aberration := 0.0
var _desaturate := 0.0
var _fade := 1.0
var _blood := 0.0
var _focus := 0.0
var _haze := 0.0
var _scope := 0.0
var _scope_angle := 0.0

var _hits := PackedVector4Array()
var _style := PackedVector4Array()
var _streaks := 0
var _warm := 8


func _ready() -> void:
	layer = -1

	_hits.resize(SLOTS)
	_style.resize(SLOTS)

	_grade_rect = _cover(_grade.material)
	_cover(_overlay.material)


func add_hit(entry: Vector2, inward: Vector2, strength: float) -> void:
	var weakest := 0
	for i in SLOTS:
		var hit := _hits[i]
		if _style[i].z > 0.0 and Vector2(hit.x, hit.y).distance_to(entry) < streak_merge:
			var merged := Vector2(hit.x, hit.y).lerp(entry, 0.5)
			_hits[i] = Vector4(merged.x, merged.y, inward.x, inward.y)
			_style[i] = Vector4(_style[i].x, 1.0, minf(_style[i].z + strength * 0.6, 1.0), 0.0)
			return

		if _style[i].z < _style[weakest].z:
			weakest = i

	_hits[weakest] = Vector4(entry.x, entry.y, inward.x, inward.y)
	_style[weakest] = Vector4(randf_range(1.0, 50.0), 1.0, strength, 0.0)
	_streaks += 1


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.05)
	var k := 1.0 - exp(-smoothing * real)
	_vignette = lerpf(_vignette, vignette + base_vignette, k)
	_aberration = lerpf(_aberration, aberration, k)
	_desaturate = lerpf(_desaturate, desaturate, k)
	_fade = lerpf(_fade, fade, k)
	_blood = lerpf(_blood, blood, k)
	_focus = lerpf(_focus, focus, k)
	_haze = lerpf(_haze, haze, k)
	_scope = lerpf(_scope, scope, k)
	_scope_angle = lerp_angle(_scope_angle, scope_dir.angle(), 1.0 - exp(-10.0 * real))

	_overlay.send(&"vignette", _vignette)
	_overlay.send(&"fade", _fade)
	_overlay.send(&"scope", _scope)
	_overlay.send(&"scope_dir", Vector2.from_angle(_scope_angle))
	_fade_streaks(real)

	var graded := (
		_aberration > 0.0004
		or _desaturate > 0.004
		or _blood > 0.004
		or maxf(_focus, _haze) > 0.01
	)
	_warm = maxi(_warm - 1, 0)
	graded = graded or _warm > 0
	_grade_rect.visible = graded
	if graded:
		_grade.send(&"aberration", _aberration)
		_grade.send(&"desaturate", _desaturate)
		_grade.send(&"blood", _blood)
		_grade.send(&"focus", _focus)
		_grade.send(&"haze", _haze)
		_grade.send(&"scope_dir", Vector2.from_angle(_scope_angle))
		_grade.send(&"scope_anchor", scope_anchor)


func _fade_streaks(real: float) -> void:
	if _streaks == 0:
		return

	var alive := 0
	for i in SLOTS:
		var style := _style[i]
		if style.z > 0.0:
			var left := maxf(style.z - real / streak_time, 0.0)
			_style[i] = Vector4(style.x, maxf(style.y - strike_decay * real, 0.0), left, 0.0)
			alive += 1 if left > 0.0 else 0

	_overlay.material.set_shader_parameter(&"hits", _hits)
	_overlay.material.set_shader_parameter(&"hit_style", _style)
	_overlay.material.set_shader_parameter(&"streaking", 1.0)
	_streaks = alive
	if alive == 0:
		_overlay.material.set_shader_parameter(&"streaking", 0.0)


func _cover(material: ShaderMaterial) -> ColorRect:
	var rect := ColorRect.new()
	rect.material = material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(rect)

	return rect
