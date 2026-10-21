class_name BloodStains
extends Node3D

const SHADER := preload("res://scripts/blood/shaders/blood_stain.gdshader")

const SPLAT := 0.0
const POOL := 1.0
const STREAK := 2.0

@export var capacity := 6000
@export var pool_capacity := 48

@export_group("Pools")
@export var pool_thickness := 0.0016
@export var pool_gain := 3.2
@export var pool_max_radius := 0.8
@export var merge_reach := 0.25
@export var pool_spread := 1.6
@export var floor_depth := 2.4

class Pool:
	var centre := Vector3.ZERO
	var volume := 0.0
	var radius := 0.0
	var target := 0.0
	var checked := 0.0
	var left := 1.0
	var right := 1.0
	var salt := 0.0
	var birth := 0.0

var _material: ShaderMaterial
var _pool_material: ShaderMaterial
var _splats: MultiMesh
var _splat_next := 0
var _splat_used := 0
var _pool_mesh: MultiMesh
var _pools: Array[Pool] = []


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_pool_material = _material.duplicate() as ShaderMaterial
	_pool_material.render_priority = 1

	_splats = _make(capacity, _material)
	_pool_mesh = _make(pool_capacity, _pool_material)
	set_process(false)


func warm(on: bool) -> void:
	_splats.visible_instance_count = 1 if on else _splat_used
	_pool_mesh.visible_instance_count = 1 if on else _pools.size()


func set_clock(clock: float) -> void:
	_material.set_shader_parameter("clock", clock)
	_pool_material.set_shader_parameter("clock", clock)


func splat(point: Vector3, normal: Vector3, travel: Vector3, radius: float, stretch: float, violence: float, clock: float) -> void:
	var along := travel - normal * travel.dot(normal)
	if along.length_squared() < 0.0001:
		along = normal.cross(Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT).rotated(normal, randf() * TAU)

	along = along.normalized()
	var across := normal.cross(along) * radius * 2.0
	var lengthwise := along * radius * stretch * 2.0
	if normal.y > 0.7:
		lengthwise.z *= floor_depth
		across.z *= floor_depth

	var axes := Basis(lengthwise, across, normal)
	_put(_splat_next, Transform3D(axes, point + normal * 0.003), clock, SPLAT, violence)
	_splat_next = (_splat_next + 1) % capacity


func streak(point: Vector3, normal: Vector3, length: float, reach: float, clock: float) -> void:
	var up := Vector3.UP - normal * normal.y
	if up.length() < 0.6:
		return

	up = up.normalized()
	var axes := Basis(up.cross(normal) * 0.04, up * length, normal)
	_put(_splat_next, Transform3D(axes, point - up * length * 0.5 + normal * 0.0035), clock, STREAK, reach)
	_splat_next = (_splat_next + 1) % capacity


func feed(point: Vector3, volume: float, starts: bool, clock: float) -> void:
	volume *= pool_gain
	var pool: Pool
	for other in _pools:
		var gap := Vector2(point.x - other.centre.x, point.z - other.centre.z).length()
		if absf(point.y - other.centre.y) < 0.25 and gap < other.radius + merge_reach:
			pool = other
			break

	if pool == null:
		if not starts:
			return

		pool = _new_pool(point, clock)

	var total := pool.volume + volume
	pool.centre += (point - pool.centre) * (volume / total) * 0.4
	pool.volume = total
	pool.target = minf(sqrt(total / pool_thickness / PI), pool_max_radius)
	if pool.target > pool.checked * 1.08:
		pool.checked = pool.target
		pool.left = _floor_reach(pool, -1.0)
		pool.right = _floor_reach(pool, 1.0)

	set_process(true)


func _process(delta: float) -> void:
	var busy := false
	var step := 1.0 - exp(-pool_spread * delta)
	for i in _pools.size():
		var pool := _pools[i]
		if is_equal_approx(pool.radius, pool.target):
			continue

		pool.radius = lerpf(pool.radius, pool.target, step)
		if absf(pool.target - pool.radius) < 0.002:
			pool.radius = pool.target

		_place(i)
		busy = true

	set_process(busy)


func _new_pool(point: Vector3, clock: float) -> Pool:
	var pool := Pool.new()
	pool.centre = point
	pool.salt = randf() * 10.0 + 1.0
	pool.birth = clock
	if _pools.size() < pool_capacity:
		_pools.append(pool)
		_pool_mesh.visible_instance_count = _pools.size()
		return pool

	var oldest := 0
	for i in _pools.size():
		if _pools[i].birth < _pools[oldest].birth:
			oldest = i

	_pools[oldest] = pool
	return pool


func _floor_reach(pool: Pool, side: float) -> float:
	var space := get_world_3d().direct_space_state
	var reach := pool.target
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = 1
	while reach > 0.05:
		var from := pool.centre + Vector3(side * reach * 0.9, 0.15, 0.0)
		query.from = from
		query.to = from + Vector3.DOWN * 0.4
		if not space.intersect_ray(query).is_empty():
			break

		reach *= 0.8

	return reach


func _place(index: int) -> void:
	var pool := _pools[index]
	var grown := maxf(pool.radius, 0.001)
	var scale_to := grown / maxf(pool.target, 0.001)
	var left := minf(pool.left * scale_to, grown)
	var right := minf(pool.right * scale_to, grown)
	var width := left + right
	var depth := minf(grown * floor_depth * 0.5, 1.2) * 2.0
	var axes := Basis(Vector3.RIGHT * width, Vector3.FORWARD * depth, Vector3.UP)
	var shade := 0.85 + fmod(pool.salt, 1.0) * 0.3
	var middle := pool.centre + Vector3((right - left) * 0.5, 0.004, 0.0)
	_pool_mesh.set_instance_transform(index, Transform3D(axes, middle))
	_pool_mesh.set_instance_color(index, Color(shade, shade, shade, 0.97))
	_pool_mesh.set_instance_custom_data(index, Color(pool.birth, pool.salt, POOL, 0.0))


func _make(count: int, material: ShaderMaterial) -> MultiMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.use_custom_data = true
	multi.mesh = quad
	multi.instance_count = count
	multi.visible_instance_count = 0

	var holder := MultiMeshInstance3D.new()
	holder.multimesh = multi
	holder.material_override = material
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.custom_aabb = AABB(Vector3.ONE * -5000.0, Vector3.ONE * 10000.0)
	add_child(holder)
	return multi


func _put(index: int, xf: Transform3D, clock: float, kind: float, extra: float) -> void:
	var shade := randf_range(0.8, 1.2)
	_splats.set_instance_transform(index, xf)
	_splats.set_instance_color(index, Color(shade, shade, shade, 0.96))
	_splats.set_instance_custom_data(index, Color(clock, randf() * 10.0 + 1.0, kind, extra))
	_splat_used = maxi(_splat_used, index + 1)
	_splats.visible_instance_count = _splat_used
