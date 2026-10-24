class_name ScreenFx
extends CanvasLayer

const SHADER := preload("res://scripts/camera/shaders/screen_fx.gdshader")
const SLOTS := 4

@export var base_vignette := 0.12
@export var grain := 0.02
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

var _material := ShaderMaterial.new()
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


func _ready() -> void:
	layer = -1

	_hits.resize(SLOTS)
	_style.resize(SLOTS)
	_material.shader = SHADER
	_material.set_shader_parameter(&"grain", grain)

	var rect := ColorRect.new()
	rect.material = _material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(rect)


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

	for i in SLOTS:
		var style := _style[i]
		if style.z > 0.0:
			_style[i] = Vector4(style.x, maxf(style.y - strike_decay * real, 0.0), maxf(style.z - real / streak_time, 0.0), 0.0)

	_material.set_shader_parameter(&"vignette", _vignette)
	_material.set_shader_parameter(&"aberration", _aberration)
	_material.set_shader_parameter(&"desaturate", _desaturate)
	_material.set_shader_parameter(&"fade", _fade)
	_material.set_shader_parameter(&"blood", _blood)
	_material.set_shader_parameter(&"focus", _focus)
	_material.set_shader_parameter(&"haze", _haze)
	_material.set_shader_parameter(&"scope", _scope)
	_material.set_shader_parameter(&"scope_dir", Vector2.from_angle(_scope_angle))
	_material.set_shader_parameter(&"scope_anchor", scope_anchor)
	_material.set_shader_parameter(&"hits", _hits)
	_material.set_shader_parameter(&"hit_style", _style)
