class_name StaticBatch
extends RefCounted

const CELL := 12.0


static func run(map: Node3D) -> void:
	var groups := { }
	var originals: Array[Node3D] = []
	for node in map.find_children("*", "Node3D", true, false):
		var piece := node as Node3D
		if not piece.scene_file_path.begins_with("res://assets/") or not piece.visible:
			continue

		originals.append(piece)
		var shadows := not map.get_node("Backdrop").is_ancestor_of(piece)
		var cell := floori(piece.global_position.x / CELL)
		var meshes := piece.find_children("*", "MeshInstance3D", true, false)
		for i in meshes.size():
			var mesh := meshes[i] as MeshInstance3D
			var key := "%s|%d|%d|%s" % [piece.scene_file_path, cell, i, shadows]
			if not groups.has(key):
				groups[key] = { "mesh": mesh.mesh, "shadows": shadows, "transforms": [] }

			var local := piece.global_transform.affine_inverse() * mesh.global_transform
			(groups[key]["transforms"] as Array).append(piece.global_transform * local)

	var holder := Node3D.new()
	holder.name = &"Batched"
	map.add_child(holder)
	for key in groups:
		var group: Dictionary = groups[key]
		var transforms: Array = group["transforms"]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = group["mesh"]
		multi.instance_count = transforms.size()
		for i in transforms.size():
			multi.set_instance_transform(i, transforms[i])

		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		if not group["shadows"]:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		holder.add_child(instance)

	for piece in originals:
		piece.queue_free()
