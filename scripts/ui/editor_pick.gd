class_name EditorPick
extends RefCounted

const BONE_RADIUS := 0.2
const REACH := 0.3
const ITEMS := [WeaponPickup.GROUP, AmmoPickup.GROUP]
const PROPS := &"props"


static func at(tree: SceneTree, point: Vector3, items: bool, skip: CharacterMovement) -> Node3D:
	var best: Node3D = null
	var best_gap := REACH
	for node in tree.get_nodes_in_group(CharacterMovement.GROUP):
		var body := node as CharacterMovement
		if body == skip or body.is_queued_for_deletion() or not (items or body.health.alive):
			continue

		var gap := _bone_gap(body, point)
		if gap < best_gap:
			best = body
			best_gap = gap

	if not items:
		return best

	for group in ITEMS:
		for node in tree.get_nodes_in_group(group):
			var item := node as RigidBody3D
			if item.is_queued_for_deletion():
				continue

			var gap := _box_gap(item, point)
			if gap <= best_gap:
				best = item
				best_gap = gap

	for node in tree.get_nodes_in_group(PROPS):
		var prop := node as Node3D
		if prop.is_queued_for_deletion():
			continue

		var gap := _prop_gap(prop, point)
		if gap < best_gap:
			best = prop
			best_gap = gap

	return best


static func corners(node: Node3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	if node is CharacterMovement:
		for bone in _bones(node as CharacterMovement):
			var spot := (bone as Node3D).global_position
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					points.append(spot + Vector3(sx, sy, 0.0) * BONE_RADIUS)

		return points

	if node.has_meta(&"pick_box"):
		var box: AABB = node.get_meta(&"pick_box")
		for i in 8:
			points.append(node.global_transform * box.get_endpoint(i))

		return points

	for child in node.get_children():
		var collider := child as CollisionShape3D
		if collider == null:
			continue

		var half := (collider.shape as BoxShape3D).size * 0.5
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					points.append(node.global_transform * (collider.position + Vector3(sx, sy, sz) * half))

	return points


static func _bones(body: CharacterMovement) -> Array[Node]:
	return body.health.ragdoll.find_children("*", "PhysicalBone3D", false, false)


static func _bone_gap(body: CharacterMovement, point: Vector3) -> float:
	var gap := INF
	for bone in _bones(body):
		var spot := (bone as Node3D).global_position
		gap = minf(gap, Vector2(spot.x - point.x, spot.y - point.y).length() - BONE_RADIUS)

	return gap


static func _box_gap(item: RigidBody3D, point: Vector3) -> float:
	var local := item.global_transform.affine_inverse() * point
	var gap := INF
	for child in item.get_children():
		var collider := child as CollisionShape3D
		if collider == null:
			continue

		var outside := (local - collider.position).abs() - (collider.shape as BoxShape3D).size * 0.5
		gap = minf(gap, Vector2(maxf(outside.x, 0.0), maxf(outside.y, 0.0)).length())

	return gap


static func _prop_gap(prop: Node3D, point: Vector3) -> float:
	var box: AABB = prop.get_meta(&"pick_box")
	var local := prop.global_transform.affine_inverse() * point
	var outside := (local - box.get_center()).abs() - box.size * 0.5
	return Vector2(maxf(outside.x, 0.0), maxf(outside.y, 0.0)).length()
