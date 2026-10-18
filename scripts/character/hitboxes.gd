class_name Hitboxes
extends Node
## Gives every ragdoll bone a hit volume shaped like what you see (the hull of
## its visible meshes: vest, pack, helmet and all). The physics shapes the ragdoll
## stands on are much smaller than the body, so bullets aimed at the legs or the
## gaps between them would otherwise pass straight through.

const LAYER := 16

## The hull points of every mesh seen so far. Working one out takes a good part
## of a second, and every body of a kind wears the very same meshes (see
## BodyLook), so only the first one pays.
static var _hulls := { }

@export var ragdoll: PhysicalBoneSimulator3D


## The bone a bullet hit, whether it struck the bone itself or its hit volume.
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


static func _hull(mesh: Mesh) -> PackedVector3Array:
	if not _hulls.has(mesh):
		_hulls[mesh] = mesh.create_convex_shape(true, true).points

	return _hulls[mesh]


func _add(bone: PhysicalBone3D) -> void:
	var points := PackedVector3Array()
	var to_bone := bone.global_transform.affine_inverse()

	for node in bone.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.visible or mesh.mesh == null:
			continue

		var local := to_bone * mesh.global_transform
		for p in _hull(mesh.mesh):
			points.append(local * p)

	if points.is_empty():
		return

	var hull := ConvexPolygonShape3D.new()
	hull.points = points

	var area := Area3D.new()
	area.name = &"Hitbox"
	area.collision_layer = LAYER
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta(&"bone", bone)

	var shape := CollisionShape3D.new()
	shape.shape = hull
	area.add_child(shape)
	bone.add_child(area)
