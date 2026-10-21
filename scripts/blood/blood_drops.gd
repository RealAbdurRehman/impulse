class_name BloodDrops
extends Node3D

const SHADER := preload("res://scripts/blood/shaders/blood_drop.gdshader")
const STRIDE := 16

@export var capacity := 700
@export var gravity := 11.0
@export var drag := 0.0009
@export var flight := 3.0
@export var splat_scale := 6.5
@export_flags_3d_physics var surfaces := 1

var stains: BloodStains
var clock := 0.0

var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _size := PackedFloat32Array()
var _left := PackedFloat32Array()
var _drip := PackedByteArray()
var _next := 0
var _live := 0
var _buffer := PackedFloat32Array()
var _multi: MultiMesh
var _query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	_pos.resize(capacity)
	_vel.resize(capacity)
	_size.resize(capacity)
	_left.resize(capacity)
	_drip.resize(capacity)
	_buffer.resize(capacity * STRIDE)
	_query.collision_mask = surfaces

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE

	_multi = MultiMesh.new()
	_multi.transform_format = MultiMesh.TRANSFORM_3D
	_multi.use_colors = true
	_multi.mesh = quad
	_multi.instance_count = capacity
	_multi.visible_instance_count = 0

	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.render_priority = 2

	var holder := MultiMeshInstance3D.new()
	holder.multimesh = _multi
	holder.material_override = material
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.custom_aabb = AABB(Vector3.ONE * -5000.0, Vector3.ONE * 10000.0)
	add_child(holder)
	set_physics_process(false)


func warm(on: bool) -> void:
	_multi.visible_instance_count = 1 if on else 0


func spawn(pos: Vector3, vel: Vector3, size: float, drip := false) -> void:
	_drip[_next] = int(drip)
	_pos[_next] = pos
	_vel[_next] = vel
	_size[_next] = size
	_left[_next] = flight
	_next = (_next + 1) % capacity
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	var out := 0
	for i in capacity:
		if _left[i] <= 0.0:
			continue

		_left[i] -= delta
		var size := _size[i]
		var vel := _vel[i]
		vel.y -= gravity * lerpf(0.55, 1.0, clampf(size / 0.02, 0.0, 1.0)) * delta
		vel *= maxf(1.0 - drag / size * vel.length() * delta, 0.0)

		var from := _pos[i]
		var to := from + vel * delta
		_query.from = from
		_query.to = to
		var hit := space.intersect_ray(_query)
		if not hit.is_empty():
			_left[i] = 0.0
			_land(hit.position, hit.normal, vel, size, _drip[i] == 1)
			continue

		_pos[i] = to
		_vel[i] = vel
		_write(out, to, vel, size, _left[i])
		out += 1

	_multi.visible_instance_count = out
	_multi.buffer = _buffer
	if out == 0:
		set_physics_process(false)


func _write(index: int, pos: Vector3, vel: Vector3, size: float, left: float) -> void:
	var speed := vel.length()
	var axis := vel / maxf(speed, 0.001)
	var width := clampf(size * 2.2, 0.006, 0.034)
	var length := clampf(speed * 0.009, width, width * 3.2)
	var side := axis.cross(Vector3.BACK)
	if side.length_squared() < 0.01:
		side = Vector3.UP

	side = side.normalized() * width
	var x := axis * length
	var o := index * STRIDE
	_buffer[o] = x.x
	_buffer[o + 1] = side.x
	_buffer[o + 2] = 0.0
	_buffer[o + 3] = pos.x
	_buffer[o + 4] = x.y
	_buffer[o + 5] = side.y
	_buffer[o + 6] = 0.0
	_buffer[o + 7] = pos.y
	_buffer[o + 8] = x.z
	_buffer[o + 9] = side.z
	_buffer[o + 10] = 1.0
	_buffer[o + 11] = pos.z

	var heavy := clampf(size / 0.02, 0.0, 1.0)
	_buffer[o + 12] = lerpf(1.0, 0.45, heavy)
	_buffer[o + 13] = 0.0
	_buffer[o + 14] = 0.0
	_buffer[o + 15] = clampf(left * 4.0, 0.0, 1.0) * lerpf(0.85, 1.0, heavy)


func _land(point: Vector3, normal: Vector3, vel: Vector3, size: float, drip: bool) -> void:
	var speed := vel.length()
	var along := vel - normal * vel.dot(normal)
	var glance := along.length() / maxf(speed, 0.001)
	var punch := clampf(speed * 0.22, 0.55, 1.5)
	var radius := size * splat_scale * punch * randf_range(0.6, 1.5) * (1.0 + 1.1 * pow(randf(), 5.0))
	if radius < 0.03 and randf() < 0.4:
		return

	var violence := clampf(speed / 8.0, 0.1, 1.0) * clampf(size / 0.008, 0.5, 1.0)
	stains.splat(point, normal, along, radius, 1.0 + glance * glance * 2.4, violence, clock)

	if normal.y > 0.7:
		stains.feed(point, size * size * size * 4.19, drip, clock)
	elif absf(normal.y) < 0.5 and radius > 0.04:
		var side := Vector3.UP.cross(normal).normalized()
		var runs := 1 + int(randf() < 0.3) + int(randf() < 0.12)
		for i in runs:
			var at := point + side * randf_range(-0.5, 0.5) * radius * float(i)
			stains.streak(at, normal, lerpf(0.06, 0.5, pow(randf(), 1.6)), randf_range(0.5, 1.0), clock)

	if size > 0.011 and speed > 3.0:
		for i in mini(int(size * 220.0), 5):
			var kick := normal * randf_range(0.5, 0.9) + Vector3(randf_range(-1.0, 1.0), randf_range(0.0, 0.5), randf_range(-1.0, 1.0)) * 0.7
			spawn(point + normal * 0.01, kick.normalized() * speed * randf_range(0.12, 0.3), size * randf_range(0.2, 0.4))
