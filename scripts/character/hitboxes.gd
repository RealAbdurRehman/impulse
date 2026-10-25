class_name Hitboxes
extends Node

const LAYER := 16
const POINTS_PER_MESH := 48

static var _shapes := { }
static var _spread: Array[Vector3] = []

@export var ragdoll: PhysicalBoneSimulator3D


static func bone_of(collider: Object) -> PhysicalBone3D:
	if collider is PhysicalBone3D:
		return collider

	if collider.has_meta(&"bone"):
		return collider.get_meta(&"bone") as PhysicalBone3D

	return null


func _ready() -> void:
	for bone in ragdoll.get_children():
		if bone is PhysicalBone3D:
			_add(bone)


static func _directions() -> Array[Vector3]:
	if _spread.is_empty():
		for x in [-1.0, 0.0, 1.0]:
			for y in [-1.0, 0.0, 1.0]:
				for z in [-1.0, 0.0, 1.0]:
					if x != 0.0 or y != 0.0 or z != 0.0:
						_spread.append(Vector3(x, y, z).normalized())

	return _spread


static func _reduce(points: PackedVector3Array, keep: int) -> PackedVector3Array:
	if points.size() <= keep:
		return points

	var nearest := PackedFloat32Array()
	nearest.resize(points.size())
	nearest.fill(INF)

	var picked := PackedVector3Array()
	var taken := { }
	for dir in _directions():
		var best := -INF
		var at := 0
		for i in points.size():
			var reach := points[i].dot(dir)
			if reach > best:
				best = reach
				at = i

		if not taken.has(at):
			taken[at] = true
			picked.append(points[at])

	for p in picked:
		for i in points.size():
			nearest[i] = minf(nearest[i], points[i].distance_squared_to(p))

	while picked.size() < keep:
		var far := -1.0
		var index := 0
		for i in points.size():
			if nearest[i] > far:
				far = nearest[i]
				index = i

		var chosen := points[index]
		picked.append(chosen)
		for i in points.size():
			nearest[i] = minf(nearest[i], points[i].distance_squared_to(chosen))

	return picked


func _add(bone: PhysicalBone3D) -> void:
	var to_bone := bone.global_transform.affine_inverse()
	var parts: Array[Dictionary] = []
	var key := String(bone.bone_name)

	for node in bone.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.visible or mesh.mesh == null:
			continue

		var local := to_bone * mesh.global_transform
		parts.append({ "mesh": mesh.mesh, "local": local })
		var box := mesh.mesh.get_aabb()
		key += "|%s|%s|%s|%s|%s|%s" % [
			mesh.mesh.get_class(),
			str(box.position.snapped(Vector3.ONE * 0.0001)),
			str(box.size.snapped(Vector3.ONE * 0.0001)),
			str(local.origin.snapped(Vector3.ONE * 0.0001)),
			str(local.basis.x.snapped(Vector3.ONE * 0.0001)),
			str(local.basis.y.snapped(Vector3.ONE * 0.0001)),
		]

	if parts.is_empty():
		return

	if not _shapes.has(key):
		var points := PackedVector3Array()
		for part in parts:
			var mesh_points := (part.mesh as Mesh).create_convex_shape(true, false).points
			for p in _reduce(mesh_points, POINTS_PER_MESH):
				points.append((part.local as Transform3D) * p)

		var hull := ConvexPolygonShape3D.new()
		hull.points = points
		_shapes[key] = hull

	var area := Area3D.new()
	area.name = &"Hitbox"
	area.collision_layer = LAYER
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta(&"bone", bone)

	var shape := CollisionShape3D.new()
	shape.shape = _shapes[key]
	area.add_child(shape)
	bone.add_child(area)
