class_name EnemyMark
extends MeshInstance3D

const SHADER := preload("res://scripts/enemy/shaders/enemy_mark.gdshader")
const FROM := 0.1
const SIZE := 0.66
const HEIGHT := 2.15
const WARM_FRAMES := 4

var _material := ShaderMaterial.new()
var _target := 0.0
var _level := 0.0
var _shown := 0.0
var _want := false
var _bang := false
var _age := 9.0
var _clock := randf() * TAU
var _warm := WARM_FRAMES


func _init() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * SIZE
	mesh = quad
	_material.shader = SHADER
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 2.0
	position = Vector3(0.0, HEIGHT, 0.0)
	_material.set_shader_parameter(&"fade", 0.0)
	_material.set_shader_parameter(&"seed", float(randi() % 64))


func show_state(awareness: float, alarm: bool) -> void:
	_want = alarm or awareness >= FROM
	_target = awareness
	if alarm:
		if not _bang:
			_age = 0.0

		_bang = true
	elif _want:
		_bang = false

	if _want and not visible:
		visible = true
		set_process(true)


func _process(delta: float) -> void:
	_clock += delta
	_age += delta
	_shown = move_toward(_shown, 1.0 if _want else 0.0, delta * (9.0 if _want else 4.0))
	_level = lerpf(_level, _target, 1.0 - exp(-8.0 * delta))

	if _warm > 0:
		_warm -= 1
	elif _shown <= 0.0 and not _want:
		_level = 0.0
		visible = false
		set_process(false)
		return

	var level := 1.0 if _bang else _level
	var base := lerpf(0.72, 1.0, smoothstep(FROM, 0.6, level))
	var motion := 1.0 + 0.04 * sin(_clock * lerpf(4.0, 14.0, level))
	if _bang:
		motion = 1.0 + 0.3 * exp(-14.0 * _age)

	var appear := 1.0 - pow(1.0 - _shown, 2.0)
	scale = Vector3.ONE * base * motion * lerpf(0.6, 1.0, appear)
	position.y = HEIGHT + 0.025 * sin(_clock * 2.2)

	_material.set_shader_parameter(&"fade", _shown * lerpf(0.7, 1.0, smoothstep(FROM, 0.5, level)))
	_material.set_shader_parameter(&"gauge", _level)
	_material.set_shader_parameter(&"bang", 1.0 if _bang else 0.0)
	_material.set_shader_parameter(&"age", _age)
