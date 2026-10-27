class_name AmmoPickup
extends RigidBody3D

const GROUP := &"ammo_pickups"
const OUTLINE_SHADER := preload("res://scripts/weapons/shaders/outline.gdshader")
const GLOW := Color(0.86, 0.72, 0.45)
const MIN_SIZE := 0.03
const SCALE := 1.5

static var _smooth := { }

@export var type: StringName = &"pistol"
@export var count := 12

var _outline: ShaderMaterial


static func spawn(
	parent: Node,
	kind: StringName,
	amount: int,
	at: Vector3,
	velocity: Vector3,
) -> AmmoPickup:
	var pickup := AmmoPickup.new()
	pickup.type = kind
	pickup.count = amount
	parent.add_child(pickup)
	pickup.global_position = at
	pickup.reset_physics_interpolation()
	pickup.linear_velocity = velocity
	return pickup


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = 4
	collision_mask = 1
	axis_lock_linear_z = true
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	mass = 0.5
	linear_damp = 0.3
	angular_damp = 0.5

	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.9
	physics_material_override.bounce = 0.1
	_build()


func _build() -> void:
	var stats := AmmoLoot.GUNS[type] as WeaponStats
	var gun := stats.scene.instantiate() as Node3D
	var part := gun.get_node(NodePath(stats.spare_mag_part)) as Node3D
	gun.remove_child(part)
	part.transform = Transform3D(Basis.from_scale(gun.scale * SCALE), Vector3.ZERO) * part.transform
	gun.free()
	_show(part)
	add_child(part)

	var width := _bounds(part).size.x
	var copies := clampi(ceili(float(count) / float(stats.magazine_size)), 1, 2)
	for i in range(1, copies):
		var extra := part.duplicate() as Node3D
		extra.position.x += float(i) * width * 1.15
		add_child(extra)

	var meshes := find_children("*", "MeshInstance3D", true, false)
	var box := _bounds(self)
	for mesh in meshes:
		_add_hull(mesh as MeshInstance3D)

	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(box.size.x, MIN_SIZE), maxf(box.size.y, MIN_SIZE), maxf(box.size.z, MIN_SIZE))
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = box.get_center()
	add_child(collider)


func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		var m := mesh as MeshInstance3D
		var bounds := _relative(m) * m.mesh.get_aabb()
		box = bounds if first else box.merge(bounds)
		first = false

	return box


func _show(node: Node3D) -> void:
	node.visible = true
	for child in node.find_children("*", "Node3D", true, false):
		(child as Node3D).visible = true


func _add_hull(mesh: MeshInstance3D) -> void:
	if _outline == null:
		_outline = ShaderMaterial.new()
		_outline.shader = OUTLINE_SHADER
		_outline.set_shader_parameter(&"color", GLOW)
		_outline.set_shader_parameter(&"width", 0.005)

	if not _smooth.has(mesh.mesh):
		_smooth[mesh.mesh] = _smoothed(mesh.mesh)

	var hull := MeshInstance3D.new()
	hull.mesh = _smooth[mesh.mesh]
	hull.material_override = _outline
	hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.add_child(hull)


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
