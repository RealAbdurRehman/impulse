class_name WeaponPickup
extends RigidBody3D

const GROUP := &"weapon_pickups"
const MIN_DEPTH := 0.03
const OUTLINE_SHADER := preload("res://scripts/weapons/shaders/outline.gdshader")

static var _smooth := { }

@export var stats: WeaponStats
@export var hanging := false

@export_group("Outline")
@export var outline_color := Color.WHITE
@export var outline_width := 0.008

@export_group("Body")
@export var friction := 0.9
@export var bounce := 0.1

var ammo := -1

var _outline: ShaderMaterial
var _hulls: Array[MeshInstance3D] = []
var _bounds := AABB()


static func spawn(
	parent: Node,
	weapon_stats: WeaponStats,
	remaining: int,
	at: Transform3D,
	velocity: Vector3,
	spin: float,
) -> void:
	var pickup := WeaponPickup.new()
	pickup.stats = weapon_stats
	pickup.ammo = remaining

	parent.add_child(pickup)
	pickup.global_transform = at
	pickup.reset_physics_interpolation()
	pickup.linear_velocity = velocity
	pickup.angular_velocity = Vector3(randf_range(-spin, spin), randf_range(-spin, spin), spin)


func _ready() -> void:
	add_to_group(GROUP)

	collision_layer = 4
	collision_mask = 1
	axis_lock_linear_z = true
	mass = 3.0
	linear_damp = 0.2
	angular_damp = 0.2
	freeze = hanging

	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = friction
	physics_material_override.bounce = bounce

	if ammo < 0:
		ammo = stats.magazine_size

	var gun := stats.scene.instantiate() as Node3D
	for part in [stats.spare_mag_part, stats.feed_part, stats.casing_part]:
		(gun.get_node(NodePath(part)) as Node3D).visible = false

	add_child(gun)

	for m in gun.find_children("*", "MeshInstance3D", true, false):
		var mesh := m as MeshInstance3D
		if mesh.is_visible_in_tree():
			_add_hull(mesh)

			var box := _relative(mesh) * mesh.mesh.get_aabb()
			_bounds = box if _bounds.size == Vector3.ZERO else _bounds.merge(box)

			var part := BoxShape3D.new()
			part.size = Vector3(box.size.x, box.size.y, maxf(box.size.z, MIN_DEPTH))

			var collider := CollisionShape3D.new()
			collider.shape = part
			collider.position = box.get_center()
			add_child(collider)


func local_center() -> Vector3:
	return _bounds.get_center()


func center() -> Vector3:
	return global_transform * _bounds.get_center()


func highlight(on: bool) -> void:
	for hull in _hulls:
		hull.visible = on


func _add_hull(mesh: MeshInstance3D) -> void:
	if _outline == null:
		_outline = ShaderMaterial.new()
		_outline.shader = OUTLINE_SHADER
		_outline.set_shader_parameter(&"color", outline_color)
		_outline.set_shader_parameter(&"width", outline_width)

	if not _smooth.has(mesh.mesh):
		_smooth[mesh.mesh] = _smoothed(mesh.mesh)

	var hull := MeshInstance3D.new()
	hull.mesh = _smooth[mesh.mesh]
	hull.material_override = _outline
	hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hull.visible = false
	mesh.add_child(hull)
	_hulls.append(hull)


func _smoothed(source: Mesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array

		var sums := { }
		for i in verts.size():
			var key := Vector3i((verts[i] * 10000.0).round())
			sums[key] = sums.get(key, Vector3.ZERO) + normals[i]

		for i in verts.size():
			normals[i] = (sums[Vector3i((verts[i] * 10000.0).round())] as Vector3).normalized()

		arrays[Mesh.ARRAY_NORMAL] = normals
		out.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)

	return out


func _relative(node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n := node
	while n != self:
		t = n.transform * t
		n = n.get_parent()

	return t
