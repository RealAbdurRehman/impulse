class_name EnemyLaser
extends RefCounted

const BEAM_SHADER := preload("res://scripts/enemy/shaders/laser_beam.gdshader")
const DOT_SHADER := preload("res://scripts/enemy/shaders/laser_dot.gdshader")
const BEAM_WIDTH := 0.1
const DOT_SIZE := 0.34

var _beam := MeshInstance3D.new()
var _beam_material := ShaderMaterial.new()
var _dot := MeshInstance3D.new()
var _dot_material := ShaderMaterial.new()
var _light := OmniLight3D.new()


func _init(parent: Node3D) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE

	_beam_material.shader = BEAM_SHADER
	_beam_material.set_shader_parameter("width_m", BEAM_WIDTH)
	_beam_material.set_shader_parameter("seed", randf() * 40.0)
	_beam_material.render_priority = 3

	_dot_material.shader = DOT_SHADER
	_dot_material.render_priority = 4

	for part: MeshInstance3D in [_beam, _dot]:
		part.mesh = quad
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.top_level = true
		part.visible = false

	_beam.material_override = _beam_material
	_dot.material_override = _dot_material

	_light.light_color = Color(1.0, 0.1, 0.06)
	_light.omni_range = 0.8
	_light.omni_attenuation = 2.0
	_light.shadow_enabled = false
	_light.top_level = true
	_light.visible = false

	parent.add_child.call_deferred(_beam)
	parent.add_child.call_deferred(_dot)
	parent.add_child.call_deferred(_light)


func show_beam(from: Vector3, dir: Vector3, length: float, strength: float) -> void:
	var up := Vector3(-dir.y, dir.x, 0.0)
	_beam.global_transform = Transform3D(
		Basis(dir * length, up * BEAM_WIDTH, Vector3.BACK),
		from + dir * length * 0.5,
	)
	_beam_material.set_shader_parameter("strength", strength)
	_beam_material.set_shader_parameter("length_m", length)

	var end := from + dir * length
	_dot.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * DOT_SIZE), end + Vector3(0.0, 0.0, 0.05))
	_dot_material.set_shader_parameter("strength", strength)

	_light.global_position = end - dir * 0.1 + Vector3(0.0, 0.0, 0.3)
	_light.light_energy = 0.03 + 0.14 * strength

	_beam.visible = true
	_dot.visible = true
	_light.visible = true


func hide() -> void:
	_beam.visible = false
	_dot.visible = false
	_light.visible = false
