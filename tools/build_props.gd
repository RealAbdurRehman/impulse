@tool
extends EditorScript

const SOURCE := "res://assets/props/"
const OUT := "res://scenes/props/"
const MENU := "res://scenes/ui/spawn_menu.tscn"
const GROUP := &"props"
const DOOR := preload("res://scripts/world/door.gd")
const DOOR_LEAF := preload("res://scripts/world/door_leaf.gd")
const DENSITY := 120.0
const MIN_THICK := 0.06
const MIN_SIZE := 0.05
const PLATE := 0.9
const SNAP := 1000.0
const WIDE := 0.8

const PROPS := [
	{ id = "crate_small", file = "crate_small", surface = &"wood", scale = 1.0, rigid = true },
	{ id = "crate_large", file = "crate_large", surface = &"wood", scale = 1.5, rigid = true },
	{ id = "crate_metal", file = "crate_metal", surface = &"metal", scale = 0.6, rigid = true },
	{ id = "barrel_steel", file = "barrel_steel", surface = &"metal", scale = 1.3, rigid = true },
	{
		id = "barrel_plastic",
		file = "barrel_plastic",
		surface = &"plastic",
		tint = Color(0.12, 0.28, 0.85),
		scale = 0.01,
		rigid = true,
	},
	{
		id = "water_tank",
		file = "water_tank",
		surface = &"plastic",
		tint = Color(0.86, 0.87, 0.88),
		scale = 0.015,
		rigid = true,
	},
	{ id = "wood_pallet", file = "wood_pallet", surface = &"wood", scale = 0.01, rigid = true },
	{ id = "dumpster", file = "dumpster", surface = &"metal", scale = 0.5, rigid = true },
	{
		id = "concrete_barrier",
		file = "concrete_barrier",
		surface = &"concrete",
		scale = 0.017,
		across = true,
	},
	{ id = "ramp", file = "ramp", surface = &"wood", scale = 2.0 },
	{ id = "brick_wall", file = "factory", piece = "Factory_modularKit_01", across = true },
	{ id = "brick_wall_half", file = "factory", piece = "Factory_modularKit_20", across = true },
	{ id = "doorway_wall", file = "factory", piece = "Factory_modularKit_09", across = true },
	{ id = "window_wall_wide", file = "factory", piece = "Factory_modularKit_03", across = true },
	{ id = "window_wall_panes", file = "factory", piece = "Factory_modularKit_36", across = true },
	{
		id = "steel_door",
		file = "factory",
		piece = "Factory_modularKit_17",
		across = true,
		surface = &"metal",
		door = true,
	},
	{ id = "glass_window", file = "factory", piece = "Factory_modularKit_39", across = true },
	{ id = "concrete_pillar", file = "factory", piece = "Factory_modularKit_28" },
	{ id = "low_wall", file = "factory", piece = "Factory_modularKit_70", across = true },
	{ id = "concrete_block", file = "factory", piece = "Factory_modularKit_74" },
	{ id = "stairs_rail", file = "factory", piece = "Factory_modularKit_78" },
	{
		id = "stairs_right",
		steps = 12,
		rise = 0.2,
		run = 0.28,
		depth = 1.5,
		surface = &"concrete",
		material = "concrete",
	},
	{
		id = "stairs_left",
		steps = 12,
		rise = 0.2,
		run = 0.28,
		depth = 1.5,
		surface = &"concrete",
		material = "concrete",
		flip = true,
	},
	{
		id = "platform_large",
		box = Vector3(4.0, 0.3, 2.0),
		surface = &"concrete",
		material = "concrete",
	},
	{
		id = "platform_small",
		box = Vector3(2.0, 0.2, 1.5),
		surface = &"concrete",
		material = "concrete",
	},
	{ id = "steel_plate", box = Vector3(3.0, 0.1, 1.5), surface = &"metal", material = "metal" },
]


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var folder := DirAccess.open(OUT)
	for old in folder.get_files():
		folder.remove(old)

	var kit: Node = load(SOURCE + "factory.glb").instantiate()
	var paths: Array[String] = []
	for entry in PROPS:
		paths.append(_build(entry, kit))

	kit.free()
	_register(paths)


func _build(entry: Dictionary, kit: Node) -> String:
	var parts := _built(entry, kit) if entry.has("box") or entry.has("steps") else _parts(
		entry,
		kit,
	)
	var bounds := _bounds_of(parts)
	var anchor := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	for part in parts:
		part.xform = Transform3D(Basis.IDENTITY, -anchor) * part.xform

	bounds.position -= anchor
	var forced: StringName = entry.get("surface", &"")
	var rigid: bool = entry.get("rigid", false)

	var root: Node3D
	if rigid:
		var body := RigidBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 1
		body.axis_lock_linear_z = true
		body.axis_lock_angular_x = true
		body.axis_lock_angular_y = true
		body.mass = maxf(bounds.get_volume() * DENSITY, 1.0)
		body.linear_damp = 0.1
		body.angular_damp = 0.2
		body.physics_material_override = PhysicsMaterial.new()
		body.physics_material_override.friction = 0.8
		body.physics_material_override.bounce = 0.1
		root = body
	else:
		root = Node3D.new()

	root.name = entry.id
	root.set_meta(&"surface", forced)
	root.set_meta(&"pick_box", bounds)
	root.add_to_group(GROUP, true)
	if entry.has("tint"):
		root.set_meta(&"tint", entry.tint)

	var door: bool = entry.get("door", false)
	var holder: Node3D = root
	var shift := Vector3.ZERO
	if door:
		root.set_script(DOOR)
		shift = Vector3(0.0, 0.0, bounds.position.z)
		var leaf := AnimatableBody3D.new()
		leaf.set_script(DOOR_LEAF)
		leaf.name = "Leaf"
		leaf.position = shift
		leaf.collision_layer = 1
		leaf.sync_to_physics = true
		leaf.set_meta(&"surface", forced)
		root.add_child(leaf)
		var shape := _box_shape(bounds)
		shape.position -= shift
		leaf.add_child(shape)
		holder = leaf

	for part in parts:
		var shown := MeshInstance3D.new()
		shown.mesh = part.mesh
		shown.transform = Transform3D(Basis.IDENTITY, -shift) * part.xform
		holder.add_child(shown)

	var report := ""
	if rigid:
		root.add_child(_box_shape(bounds))
		report = "box mass %.0f" % (root as RigidBody3D).mass
	elif door:
		report = "hinged door"
	else:
		report = _colliders(root, parts, forced)

	_own(root, root)
	var packed := PackedScene.new()
	packed.pack(root)
	var path := "%s%s.tscn" % [OUT, entry.id]
	ResourceSaver.save(packed, path)
	print(
		"%-18s %-9s size %s  %s"
		% [entry.id, root.get_meta(&"surface"), bounds.size.snapped(Vector3.ONE * 0.01), report]
	)
	root.free()
	return path


func _box_shape(bounds: AABB) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = bounds.size
	shape.position = bounds.get_center()
	return shape


func _parts(entry: Dictionary, kit: Node) -> Array[Dictionary]:
	var scene: Node = kit if entry.file == "factory" else load(SOURCE + entry.file + ".glb").instantiate()
	var origin: Node = scene.find_child(entry.piece, true, false) if entry.has("piece") else scene
	var found: Array[Node] = []
	if origin is MeshInstance3D:
		found.append(origin)

	found.append_array(origin.find_children("*", "MeshInstance3D", true, false))

	var scale: float = entry.get("scale", 1.0)
	var raw := Basis.from_scale(Vector3.ONE * scale)
	var box := AABB()
	var first := true
	for mesh in found:
		var spot := Transform3D(raw, Vector3.ZERO) * _world(mesh)
		var bit: AABB = spot * mesh.mesh.get_aabb()
		box = bit if first else box.merge(bit)
		first = false

	var spin := box.size.x > box.size.z if entry.get("across", false) else box.size.x < box.size.z * WIDE
	var turn := Basis(Vector3.UP, PI * 0.5) if spin else Basis.IDENTITY
	var parts: Array[Dictionary] = []
	for mesh in found:
		parts.append(
			{ mesh = mesh.mesh, xform = Transform3D(turn * raw, Vector3.ZERO) * _world(mesh) }
		)

	if scene != kit:
		scene.free()

	return parts


func _built(entry: Dictionary, kit: Node) -> Array[Dictionary]:
	var material := _material(kit, entry.material)
	var sizes: Array[Vector3] = []
	var spots: Array[Vector3] = []
	if entry.has("box"):
		sizes.append(entry.box)
		spots.append(entry.box * 0.5)
	else:
		for i in int(entry.steps):
			var size := Vector3(entry.run, entry.rise * (i + 1), entry.depth)
			var column: float = (entry.steps - i - 0.5 if entry.get("flip", false) else i + 0.5) * entry.run
			sizes.append(size)
			spots.append(Vector3(column, size.y * 0.5, size.z * 0.5))

	var parts: Array[Dictionary] = []
	for i in sizes.size():
		var mesh := BoxMesh.new()
		mesh.size = sizes[i]
		mesh.material = material
		parts.append({ mesh = mesh, xform = Transform3D(Basis.IDENTITY, spots[i]) })

	return parts


func _material(kit: Node, key: String) -> StandardMaterial3D:
	for mesh in kit.find_children("*", "MeshInstance3D", true, false):
		for s in (mesh as MeshInstance3D).mesh.get_surface_count():
			var found := (mesh as MeshInstance3D).mesh.surface_get_material(s) as StandardMaterial3D
			if found != null and found.resource_name.to_lower().contains(key):
				var slab := found.duplicate() as StandardMaterial3D
				slab.uv1_triplanar = true
				slab.uv1_scale = Vector3.ONE * 0.5
				return slab

	return null


func _world(node: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var walk: Node = node
	while walk != null:
		if walk is Node3D:
			result = (walk as Node3D).transform * result

		walk = walk.get_parent()

	return result


func _bounds_of(parts: Array[Dictionary]) -> AABB:
	var box := AABB()
	var first := true
	for part in parts:
		var bit: AABB = part.xform * part.mesh.get_aabb()
		box = bit if first else box.merge(bit)
		first = false

	return box


func _colliders(root: Node3D, parts: Array[Dictionary], forced: StringName) -> String:
	var kinds := { }
	for part in parts:
		var mesh: Mesh = part.mesh
		for s in mesh.get_surface_count():
			var kind: StringName = forced if forced != &"" else _kind(mesh.surface_get_material(s))
			var arrays := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index: Variant = arrays[Mesh.ARRAY_INDEX]
			if not kinds.has(kind):
				kinds[kind] = PackedVector3Array()

			var list: PackedVector3Array = kinds[kind]
			var corners: int = verts.size() if index == null or index.is_empty() else index.size()
			for i in corners:
				list.append(
					part.xform * verts[i if index == null or index.is_empty() else index[i]]
				)

			kinds[kind] = list

	var area := { }
	var shapes := 0
	for kind in kinds:
		var body := StaticBody3D.new()
		body.name = String(kind).capitalize()
		body.collision_layer = 1
		body.set_meta(&"surface", kind)
		root.add_child(body)

		var solid := PackedVector3Array()
		area[kind] = 0.0
		for tris in _components(kinds[kind]):
			var box := _bounds_of_points(tris)
			var size := box.size
			var flat := size.min_axis_index()
			var plate := _area(tris) >= PLATE * _face(size)
			area[kind] += _area(tris)
			if size[size.max_axis_index()] < MIN_SIZE:
				continue

			if size[flat] < MIN_THICK and plate:
				var pos := box.position
				pos[flat] -= (MIN_THICK - size[flat]) * 0.5
				size[flat] = MIN_THICK
				var shape := CollisionShape3D.new()
				shape.shape = BoxShape3D.new()
				shape.shape.size = size
				shape.position = pos + size * 0.5
				body.add_child(shape)
				shapes += 1
			else:
				solid.append_array(tris)

		if not solid.is_empty():
			var shape := CollisionShape3D.new()
			shape.shape = ConcavePolygonShape3D.new()
			shape.shape.backface_collision = true
			shape.shape.set_faces(solid)
			body.add_child(shape)
			shapes += 1

	var best: StringName = area.keys()[0]
	for kind in area:
		if area[kind] > area[best]:
			best = kind

	if forced == &"":
		root.set_meta(&"surface", best)

	return "%s shapes %d" % [area.keys(), shapes]


func _kind(material: Material) -> StringName:
	var label := material.resource_name.to_lower() if material != null else ""
	if label.contains("metal") or label.contains("door"):
		return &"metal"
	if label.contains("glass"):
		return &"glass"

	return &"concrete"


func _components(tris: PackedVector3Array) -> Array:
	var count := tris.size() / 3
	var parent := PackedInt32Array()
	parent.resize(count)
	for i in count:
		parent[i] = i

	var seen := { }
	for i in count:
		for k in 3:
			var key := Vector3i((tris[i * 3 + k] * SNAP).round())
			if seen.has(key):
				var a := _find(parent, i)
				var b := _find(parent, seen[key])
				parent[a] = b
			else:
				seen[key] = i

	var groups := { }
	for i in count:
		var r := _find(parent, i)
		if not groups.has(r):
			groups[r] = PackedVector3Array()

		groups[r].append_array(tris.slice(i * 3, i * 3 + 3))

	return groups.values()


func _find(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]

	return i


func _bounds_of_points(points: PackedVector3Array) -> AABB:
	var box := AABB(points[0], Vector3.ZERO)
	for p in points:
		box = box.expand(p)

	return box


func _area(tris: PackedVector3Array) -> float:
	var total := 0.0
	for i in tris.size() / 3:
		total += (tris[i * 3 + 1] - tris[i * 3]).cross(tris[i * 3 + 2] - tris[i * 3]).length() * 0.5

	return total


func _face(size: Vector3) -> float:
	var s := [size.x, size.y, size.z]
	s.sort()
	return s[1] * s[2]


func _own(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_own(child, root)


func _register(paths: Array[String]) -> void:
	var text := FileAccess.get_file_as_string(MENU)
	var strip := RegEx.create_from_string(
		"(?m)^\\[ext_resource type=\"PackedScene\"[^\\n]*path=\"res://scenes/props/[^\\n]*\\n"
	)
	text = strip.sub(text, "", true)
	text = RegEx.create_from_string("(?m)^props = .*\\n").sub(text, "", true)

	var lines := ""
	var ids: Array[String] = []
	for path in paths:
		var id := "p_" + path.get_file().get_basename()
		lines += "[ext_resource type=\"PackedScene\" path=\"%s\" id=\"%s\"]\n" % [path, id]
		ids.append("ExtResource(\"%s\")" % id)

	var script_line := "id=\"8_kind\"]\n"
	text = text.replace(script_line, script_line + lines)
	var weapons := RegEx.create_from_string("(?m)^weapons = .*\\n").search(text)
	text = text.insert(weapons.get_end(), "props = Array[PackedScene]([%s])\n" % ", ".join(ids))

	var file := FileAccess.open(MENU, FileAccess.WRITE)
	file.store_string(text)
