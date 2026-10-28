class_name ImpactDebris
extends Node3D

const CHIP_SHADER := preload("res://scripts/impacts/shaders/impact_chip.gdshader")
const SPARK_SHADER := preload("res://scripts/impacts/shaders/impact_spark.gdshader")

@export var chip_capacity := 360
@export var shard_capacity := 120
@export var spark_capacity := 180
@export var gravity := 9.8
@export var rest_speed := 0.9
@export_flags_3d_physics var surfaces := 1

class Bit:
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var axes := Basis.IDENTITY
	var spin := Vector3.ZERO
	var size := Vector3.ONE
	var color := Color.WHITE
	var left := 0.0
	var life := 0.0
	var bounce := 0.0
	var drag := 0.0
	var glow := false
	var rest := false

class Layer:
	var bits: Array[Bit] = []
	var next := 0
	var stride := 16
	var multi: MultiMesh
	var buffer := PackedFloat32Array()

var _chips := Layer.new()
var _shards := Layer.new()
var _sparks := Layer.new()
var _query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	_query.collision_mask = surfaces

	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE

	var chip_material := ShaderMaterial.new()
	chip_material.shader = CHIP_SHADER

	var shard_material := StandardMaterial3D.new()
	shard_material.vertex_color_use_as_albedo = true
	shard_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shard_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shard_material.roughness = 0.05
	shard_material.metallic_specular = 1.0
	shard_material.render_priority = 1

	var spark_material := ShaderMaterial.new()
	spark_material.shader = SPARK_SHADER
	spark_material.render_priority = 4

	_build(_chips, chip_capacity, box, chip_material, false)
	_build(_shards, shard_capacity, box, shard_material, false)
	_build(_sparks, spark_capacity, quad, spark_material, true)
	set_process(false)


func warm(on: bool) -> void:
	for layer in [_chips, _shards, _sparks]:
		layer.multi.visible_instance_count = 1 if on else 0


func chip(pos: Vector3, vel: Vector3, style: SurfaceStyle, glass: bool, colors: Array[Color]) -> void:
	var layer := _shards if glass else _chips
	var b := _take(layer)
	var scale_to := randf_range(style.debris_size.x, style.debris_size.y)
	b.pos = pos
	b.vel = vel
	b.axes = Basis(Quaternion(Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized(), randf() * TAU))
	b.spin = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * randf_range(6.0, 22.0)
	b.size = style.debris_shape * scale_to
	b.color = colors[randi() % colors.size()].srgb_to_linear()
	if glass:
		b.color.a = 0.55

	b.life = randf_range(4.0, 8.0)
	b.left = b.life
	b.bounce = style.debris_bounce
	b.drag = 0.4
	b.rest = false
	b.glow = false
	set_process(true)


func spark(pos: Vector3, vel: Vector3, color: Color, width: float, life: float) -> void:
	var b := _take(_sparks)
	b.pos = pos
	b.vel = vel
	b.size = Vector3(0.0, width, 0.0)
	b.color = color.srgb_to_linear()
	b.life = life
	b.left = life
	b.bounce = 0.45
	b.drag = 4.5
	b.rest = false
	b.glow = false
	set_process(true)


func flash(pos: Vector3, color: Color, radius: float) -> void:
	var b := _take(_sparks)
	b.pos = pos
	b.vel = Vector3.ZERO
	b.size = Vector3(radius, radius, 0.0)
	b.color = color.srgb_to_linear()
	b.life = 0.07
	b.left = b.life
	b.bounce = 0.0
	b.drag = 0.0
	b.rest = true
	b.glow = true
	set_process(true)


func _process(delta: float) -> void:
	delta = minf(delta, 0.033)
	var space := get_world_3d().direct_space_state
	var busy := _step(_chips, delta, space)
	busy = _step(_shards, delta, space) or busy
	busy = _step(_sparks, delta, space) or busy
	if not busy:
		set_process(false)


func _step(layer: Layer, delta: float, space: PhysicsDirectSpaceState3D) -> bool:
	var out := 0
	var sparks := layer == _sparks
	for b in layer.bits:
		if b.left <= 0.0:
			continue

		b.left -= delta
		if b.left <= 0.0:
			continue

		if not b.rest:
			b.vel.y -= gravity * delta
			b.vel *= maxf(1.0 - b.drag * delta, 0.0)

			var to := b.pos + b.vel * delta
			_query.from = b.pos
			_query.to = to
			var hit := space.intersect_ray(_query)
			if hit.is_empty():
				b.pos = to
			else:
				_bounce(b, hit, sparks)

			if not sparks and b.spin != Vector3.ZERO:
				b.axes = Basis(b.spin.normalized(), b.spin.length() * delta) * b.axes

		if sparks:
			_write_spark(layer, out, b)
		else:
			_write_chip(layer, out, b)

		out += 1

	layer.multi.visible_instance_count = out
	layer.multi.buffer = layer.buffer
	return out > 0


func _bounce(b: Bit, hit: Dictionary, streak: bool) -> void:
	var n: Vector3 = hit.normal
	var vn := b.vel.dot(n)
	var slide := b.vel - n * vn
	b.vel = slide * 0.72 - n * vn * b.bounce
	b.pos = hit.position + n * 0.003
	b.spin *= 0.55

	if streak:
		b.left -= b.life * 0.15
		return

	if b.vel.length() < rest_speed and n.y > 0.5:
		b.rest = true
		b.vel = Vector3.ZERO
		b.spin = Vector3.ZERO


func _write_chip(layer: Layer, index: int, b: Bit) -> void:
	var fade := clampf(b.left / 0.5, 0.0, 1.0)
	var size := b.size * fade
	var x := b.axes.x * size.x
	var y := b.axes.y * size.y
	var z := b.axes.z * size.z
	var o := index * layer.stride
	var buf := layer.buffer
	buf[o] = x.x
	buf[o + 1] = y.x
	buf[o + 2] = z.x
	buf[o + 3] = b.pos.x
	buf[o + 4] = x.y
	buf[o + 5] = y.y
	buf[o + 6] = z.y
	buf[o + 7] = b.pos.y
	buf[o + 8] = x.z
	buf[o + 9] = y.z
	buf[o + 10] = z.z
	buf[o + 11] = b.pos.z
	buf[o + 12] = b.color.r
	buf[o + 13] = b.color.g
	buf[o + 14] = b.color.b
	buf[o + 15] = b.color.a


func _write_spark(layer: Layer, index: int, b: Bit) -> void:
	var speed := b.vel.length()
	var axis := b.vel / maxf(speed, 0.001)
	var width := b.size.y
	var length := width
	var centre := b.pos
	if not b.glow:
		length = clampf(speed * 0.028, width * 2.0, 0.2)
		centre = b.pos - axis * length * 0.5
	else:
		axis = Vector3.RIGHT

	var side := axis.cross(Vector3.BACK)
	if side.length_squared() < 0.01:
		side = Vector3.UP

	side = side.normalized() * width
	var x := axis * length
	var life := b.left / b.life
	var o := index * layer.stride
	var buf := layer.buffer
	buf[o] = x.x
	buf[o + 1] = side.x
	buf[o + 2] = 0.0
	buf[o + 3] = centre.x
	buf[o + 4] = x.y
	buf[o + 5] = side.y
	buf[o + 6] = 0.0
	buf[o + 7] = centre.y
	buf[o + 8] = x.z
	buf[o + 9] = side.z
	buf[o + 10] = 1.0
	buf[o + 11] = centre.z
	buf[o + 12] = b.color.r
	buf[o + 13] = b.color.g
	buf[o + 14] = b.color.b
	buf[o + 15] = clampf(life * 2.5, 0.0, 1.0)
	buf[o + 16] = 1.0 if b.glow else 0.0
	buf[o + 17] = 0.0
	buf[o + 18] = 0.0
	buf[o + 19] = 0.0


func _take(layer: Layer) -> Bit:
	var b := layer.bits[layer.next]
	layer.next = (layer.next + 1) % layer.bits.size()
	return b


func _build(layer: Layer, capacity: int, mesh: Mesh, material: Material, custom: bool) -> void:
	for i in capacity:
		layer.bits.append(Bit.new())

	layer.stride = 20 if custom else 16
	layer.buffer.resize(capacity * layer.stride)

	layer.multi = MultiMesh.new()
	layer.multi.transform_format = MultiMesh.TRANSFORM_3D
	layer.multi.use_colors = true
	layer.multi.use_custom_data = custom
	layer.multi.mesh = mesh
	layer.multi.instance_count = capacity
	layer.multi.visible_instance_count = 0

	var holder := MultiMeshInstance3D.new()
	holder.multimesh = layer.multi
	holder.material_override = material
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.custom_aabb = AABB(Vector3.ONE * -5000.0, Vector3.ONE * 10000.0)
	add_child(holder)
