class_name Batch
extends RefCounted

static var _cache := { }

var _items := { }


func urban(name: String, at: Vector3, yaw := 0.0, size := Vector3.ONE) -> void:
	add(Kit.URBAN % name, at, yaw, size)


func nature(name: String, at: Vector3, yaw := 0.0, size := Vector3.ONE) -> void:
	add(Kit.NATURE % name, at, yaw, size)


func row(name: String, x0: float, x1: float, z: float, yaw := 0.0) -> void:
	var x := x0
	while x < x1 - 0.001:
		var length := minf(3.0, x1 - x)
		urban(name, Vector3(x + length * 0.5, 0.0, z), yaw, Vector3(length / 3.0, 1.0, 1.0))
		x += length


func pavement(width: float) -> void:
	row("sidewalks/sidewalk_straight_3m", 0.0, width, -2.5)
	row("sidewalks/sidewalk_nocurb_3m", 0.0, width, 0.5)
	frontage(width)


func frontage(width: float) -> void:
	row("sidewalks/sidewalk_nocurb_3m", 0.0, width, 3.5)
	row("sidewalks/sidewalk_straight_3m", 0.0, width, 6.5, PI)


func scatter(names: Array, rng: RandomNumberGenerator, count: int, along: Vector2, depth: Vector2, size: Vector2) -> void:
	for i in count:
		var piece: String = names[rng.randi_range(0, names.size() - 1)]
		var at := Vector3(rng.randf_range(along.x, along.y), 0.0, rng.randf_range(depth.x, depth.y))
		nature(piece, at, rng.randf() * TAU, Vector3.ONE * rng.randf_range(size.x, size.y))


func add(path: String, at: Vector3, yaw := 0.0, size := Vector3.ONE) -> void:
	if not _items.has(path):
		_items[path] = []

	_items[path].append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), at))


func commit(parent: Node3D) -> void:
	for path: String in _items:
		var placed: Array = _items[path]
		for part in _parts(path):
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = part[0]
			multi.instance_count = placed.size()
			for i in placed.size():
				multi.set_instance_transform(i, placed[i] * part[1])

			var holder := MultiMeshInstance3D.new()
			holder.multimesh = multi
			parent.add_child(holder)

	_items.clear()


static func _parts(path: String) -> Array:
	if not _cache.has(path):
		var scene := (load(path) as PackedScene).instantiate() as Node3D
		var parts := []
		for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			var local := Transform3D.IDENTITY
			var node: Node = mesh
			while node != scene:
				local = (node as Node3D).transform * local
				node = node.get_parent()

			for i in mesh.mesh.get_surface_count():
				(mesh.get_active_material(i) as BaseMaterial3D).vertex_color_use_as_albedo = false

			parts.append([mesh.mesh, local])

		scene.free()
		_cache[path] = parts

	return _cache[path]
