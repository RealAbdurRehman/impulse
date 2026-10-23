class_name ImpactMarks
extends Node3D

const SHADER := preload("res://scripts/impacts/shaders/impact_mark.gdshader")

@export var capacity := 480
@export var floor_depth := 2.4
@export_flags_3d_physics var surfaces := 1

var _multi: MultiMesh
var _next := 0
var _used := 0
var _query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	_query.collision_mask = surfaces

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE

	_multi = MultiMesh.new()
	_multi.transform_format = MultiMesh.TRANSFORM_3D
	_multi.use_colors = true
	_multi.use_custom_data = true
	_multi.mesh = quad
	_multi.instance_count = capacity
	_multi.visible_instance_count = 0

	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.render_priority = 1

	var holder := MultiMeshInstance3D.new()
	holder.multimesh = _multi
	holder.material_override = material
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.custom_aabb = AABB(Vector3.ONE * -5000.0, Vector3.ONE * 10000.0)
	add_child(holder)


func warm(on: bool) -> void:
	_multi.visible_instance_count = 1 if on else _used


func mark(point: Vector3, normal: Vector3, dir: Vector3, style: SurfaceStyle, size: float) -> void:
	var radius := randf_range(style.mark_radius.x, style.mark_radius.y) * size
	var glance := 1.0 - absf(dir.dot(normal))
	var across := 1.0

	if absf(normal.y) > 0.7:
		across = floor_depth
	else:
		var found := _visible_face(point, normal, radius)
		if found.is_empty():
			return

		point = found.position
		normal = found.normal

	var along := dir - normal * dir.dot(normal)
	if along.length_squared() < 0.0001:
		along = normal.cross(Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT).rotated(normal, randf() * TAU)

	along = along.normalized()
	var stretch := 1.0 + glance * glance * 2.5
	var x := along * radius * 2.0 * stretch
	var y := normal.cross(along) * radius * 2.0 * across
	var axes := Basis(x, y, normal)
	var xf := Transform3D(axes, point + normal * 0.003)

	_multi.set_instance_transform(_next, xf)
	_multi.set_instance_color(_next, style.mark_color.srgb_to_linear())
	_multi.set_instance_custom_data(_next, Color(randf() * 10.0, float(style.mark), glance, 0.0))
	_used = maxi(_used, _next + 1)
	_multi.visible_instance_count = _used
	_next = (_next + 1) % capacity


func _visible_face(point: Vector3, normal: Vector3, radius: float) -> Dictionary:
	var eye := get_viewport().get_camera_3d().global_position
	var inside := point - normal * (radius * 0.5 + 0.01)
	_query.from = eye
	_query.to = inside + (inside - eye).normalized() * 0.05
	return get_world_3d().direct_space_state.intersect_ray(_query)
