@tool
class_name MeshKit
extends RefCounted

var _surfaces := { }


func add(material: Material, part: Dictionary, at := Transform3D.IDENTITY) -> void:
	if not _surfaces.has(material):
		_surfaces[material] = {
			"verts": PackedVector3Array(),
			"normals": PackedVector3Array(),
			"indices": PackedInt32Array(),
		}

	var surface: Dictionary = _surfaces[material]
	var verts: PackedVector3Array = surface["verts"]
	var normals: PackedVector3Array = surface["normals"]
	var indices: PackedInt32Array = surface["indices"]

	var first := verts.size()
	var normal_basis := at.basis.inverse().transposed()
	var part_verts: PackedVector3Array = part["verts"]
	var part_normals: PackedVector3Array = part["normals"]
	for i in part_verts.size():
		verts.append(at * part_verts[i])
		normals.append((normal_basis * part_normals[i]).normalized())

	for index in part["indices"] as PackedInt32Array:
		indices.append(first + index)

	surface["verts"] = verts
	surface["normals"] = normals
	surface["indices"] = indices


func is_empty() -> bool:
	return _surfaces.is_empty()


func build() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for material in _surfaces:
		var surface: Dictionary = _surfaces[material]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = surface["verts"]
		arrays[Mesh.ARRAY_NORMAL] = surface["normals"]
		arrays[Mesh.ARRAY_INDEX] = surface["indices"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)

	return mesh


static func box(
		size: Vector3,
		radius: float,
		steps := 3,
		top := Vector2.ONE,
		bottom := Vector2.ONE,
) -> Dictionary:
	var half := size * 0.5
	var r := minf(radius, minf(half.x, minf(half.y, half.z)) * 0.999)
	var axes: Array[PackedFloat32Array] = [
		_edge_stops(half.x, r, steps),
		_edge_stops(half.y, r, steps),
		_edge_stops(half.z, r, steps),
	]

	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	var lookup := { }

	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for side in [-1.0, 1.0]:
			var grid := []
			for i in axes[u].size():
				var row := []
				for j in axes[v].size():
					var p := Vector3.ZERO
					p[axis] = half[axis] * side
					p[u] = axes[u][i]
					p[v] = axes[v][j]
					var key := Vector3i((p * 100000.0).round())
					if not lookup.has(key):
						lookup[key] = verts.size()
						verts.append(_round_off(p, half, r))

					row.append(lookup[key])

				grid.append(row)

			for i in axes[u].size() - 1:
				for j in axes[v].size() - 1:
					var a: int = grid[i][j]
					var b: int = grid[i + 1][j]
					var c: int = grid[i + 1][j + 1]
					var d: int = grid[i][j + 1]
					indices.append_array([a, b, c, a, c, d])

	if top != Vector2.ONE or bottom != Vector2.ONE:
		for i in verts.size():
			var t := verts[i].y / size.y + 0.5
			var scale := bottom.lerp(top, t)
			verts[i].x *= scale.x
			verts[i].z *= scale.y

	return _finish(verts, indices)


static func limb(rings: Array, sides := 14, cap_top := 0.0, cap_bottom := 0.0, cap_steps := 3) -> Dictionary:
	var all: Array[Vector4] = []

	if cap_top > 0.0:
		var first: Vector4 = rings[0]
		for k in range(cap_steps, 0, -1):
			var angle := float(k) / (cap_steps + 1) * PI * 0.5
			all.append(Vector4(first.x + cap_top * sin(angle), first.y * cos(angle), first.z * cos(angle), first.w))

		all.push_front(Vector4(first.x + cap_top, 0.0, 0.0, first.w))

	for stop in rings:
		all.append(stop)

	if cap_bottom > 0.0:
		var last: Vector4 = rings[rings.size() - 1]
		for k in range(1, cap_steps + 1):
			var angle := float(k) / (cap_steps + 1) * PI * 0.5
			all.append(Vector4(last.x - cap_bottom * sin(angle), last.y * cos(angle), last.z * cos(angle), last.w))

		all.append(Vector4(last.x - cap_bottom, 0.0, 0.0, last.w))

	return _revolve(all, sides)


static func ellipsoid(radii: Vector3, rings := 9, sides := 16) -> Dictionary:
	var stops: Array[Vector4] = []
	for k in rings + 1:
		var angle := PI * float(k) / rings
		var wave := sin(angle)
		stops.append(Vector4(radii.y * cos(angle), radii.x * wave, radii.z * wave, 0.0))

	return _revolve(stops, sides)


static func capsule(length: float, radius_x: float, radius_z: float, sides := 14) -> Dictionary:
	var cap := minf(radius_x, radius_z)
	var half := maxf(length * 0.5 - cap, 0.0)
	return limb(
		[Vector4(half, radius_x, radius_z, 0.0), Vector4(-half, radius_x, radius_z, 0.0)],
		sides,
		cap,
		cap,
		4,
	)


static func ring(y: float, radius_x: float, radius_z: float, centre_z := 0.0) -> Vector4:
	return Vector4(y, radius_x, radius_z, centre_z)


static func _edge_stops(half: float, radius: float, steps: int) -> PackedFloat32Array:
	var stops := PackedFloat32Array()
	for i in steps + 1:
		stops.append(-half + radius * float(i) / steps)

	for i in range(steps, -1, -1):
		stops.append(half - radius * float(i) / steps)

	return stops


static func _round_off(p: Vector3, half: Vector3, radius: float) -> Vector3:
	var inner := Vector3(
		clampf(p.x, -(half.x - radius), half.x - radius),
		clampf(p.y, -(half.y - radius), half.y - radius),
		clampf(p.z, -(half.z - radius), half.z - radius),
	)
	var offset := p - inner
	if offset.length_squared() < 0.0000000001:
		return p

	return inner + offset.normalized() * radius


static func _revolve(stops: Array[Vector4], sides: int) -> Dictionary:
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()

	for stop in stops:
		for i in sides:
			var angle := TAU * float(i) / sides
			verts.append(Vector3(stop.y * cos(angle), stop.x, stop.w + stop.z * sin(angle)))

	for j in stops.size() - 1:
		for i in sides:
			var next := (i + 1) % sides
			var a := j * sides + i
			var b := j * sides + next
			var c := (j + 1) * sides + next
			var d := (j + 1) * sides + i
			indices.append_array([a, c, b, a, d, c])

	return _finish(verts, indices)


static func _finish(verts: PackedVector3Array, indices: PackedInt32Array) -> Dictionary:
	var centre := Vector3.ZERO
	for v in verts:
		centre += v

	centre /= maxf(verts.size(), 1.0)

	var kept := PackedInt32Array()
	var sums := { }
	for t in range(0, indices.size(), 3):
		var a := indices[t]
		var b := indices[t + 1]
		var c := indices[t + 2]
		var face := (verts[c] - verts[a]).cross(verts[b] - verts[a])
		if face.length_squared() < 0.000000000001:
			continue

		var middle := (verts[a] + verts[b] + verts[c]) / 3.0
		if face.dot(middle - centre) < 0.0:
			var swap := b
			b = c
			c = swap
			face = -face

		kept.append_array([a, b, c])
		for index in [a, b, c]:
			var key := Vector3i((verts[index] * 20000.0).round())
			sums[key] = (sums[key] if sums.has(key) else Vector3.ZERO) + face

	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for i in verts.size():
		var key := Vector3i((verts[i] * 20000.0).round())
		normals[i] = (sums[key] as Vector3).normalized() if sums.has(key) else Vector3.UP

	return { "verts": verts, "normals": normals, "indices": kept }
