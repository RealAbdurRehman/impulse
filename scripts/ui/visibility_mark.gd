class_name VisibilityMark
extends MeshInstance3D

const SHADER := preload("res://scripts/ui/shaders/visibility_mark.gdshader")
const SIZE := 0.38
const HEIGHT := 2.35
const CROUCH_DROP := 0.4
const WARM_FRAMES := 4

@export var notice_range := 26.0
@export var hold_time := 1.4

var _body: CharacterMovement
var _gait: GaitDriver
var _material := ShaderMaterial.new()
var _near := false
var _alert := 0.0
var _hold := 0.0
var _scan_left := 0.0
var _fade := 0.0
var _open := 1.0
var _hidden := 0.0
var _exposure := 0.0
var _shown_alert := 0.0
var _warm := WARM_FRAMES


func _ready() -> void:
	_body = get_parent() as CharacterMovement
	_gait = _body.find_child("GaitDriver", true, false) as GaitDriver
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * SIZE
	mesh = quad
	_material.shader = SHADER
	_material.set_shader_parameter(&"fade", 0.0)
	_material.set_shader_parameter(&"seed", float(randi() % 64))
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 2.0
	position = Vector3(0.0, HEIGHT, 0.0)


func _process(delta: float) -> void:
	position.y = HEIGHT - CROUCH_DROP * _gait.crouch_amount
	if not _body.health.alive:
		_hold = 0.0
		_near = false

	_scan_left -= delta
	if _scan_left <= 0.0:
		_scan_left = 0.15
		_scan()

	var concealment := StealthZone.at(_body.global_position + Vector3.UP * 0.9)
	var speed := absf(_body.velocity.x)
	var motion := 1.0
	if speed > NoiseSource.RUN_SPEED:
		motion = 1.4
	elif speed < NoiseSource.MOVE_SPEED:
		motion = 0.7

	var stance := 0.6 if _body.crouching else 1.0
	var exposure := concealment * stance * motion / 1.4

	var relevant := _body.health.alive and (_near or concealment < 0.98)
	_hold = hold_time if relevant else maxf(_hold - delta, 0.0)

	var blend := 1.0 - exp(-8.0 * delta)
	_fade = move_toward(_fade, 1.0 if _hold > 0.0 else 0.0, delta * 5.0)
	_open = lerpf(_open, smoothstep(0.05, 0.75, exposure), blend)
	_exposure = lerpf(_exposure, exposure, blend)
	_hidden = lerpf(_hidden, 1.0 if concealment < EnemyInput.CONCEALED else 0.0, blend)
	_shown_alert = lerpf(_shown_alert, _alert, blend)

	if _warm > 0:
		_warm -= 1
	elif _fade <= 0.0:
		visible = false
		return

	visible = true
	_material.set_shader_parameter(&"fade", _fade)
	_material.set_shader_parameter(&"open", _open)
	_material.set_shader_parameter(&"hidden", _hidden)
	_material.set_shader_parameter(&"exposure", _exposure)
	_material.set_shader_parameter(&"alert", _shown_alert)


func _scan() -> void:
	_near = false
	_alert = 0.0
	var origin := _body.global_position
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var brain := node as EnemyInput
		if not brain.health.alive or not brain.hostile:
			continue

		if (brain.get_parent() as Node3D).global_position.distance_to(origin) <= notice_range:
			_near = true
			_alert = maxf(_alert, brain.warning())
