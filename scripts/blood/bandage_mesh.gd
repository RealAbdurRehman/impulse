class_name BandageMesh
extends RefCounted

const ROWS := 16
const COLUMNS := 72


static func faces(meshes: Array[MeshInstance3D], to_bone: Transform3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for instance in meshes:
		var source := instance.mesh
		var xf := to_bone * instance.global_transform
		var body: Array[int] = []
		for s in source.get_surface_count():
			var material := source.surface_get_material(s)
			if material != null and material.resource_name == &"body":
				body.append(s)

		if body.is_empty():
			out.append_array(xf * source.get_faces())
			continue

		for s in body:
			var arrays := source.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var triangles := PackedVector3Array()
			triangles.resize(indices.size())
			for i in indices.size():
				triangles[i] = verts[indices[i]]

			out.append_array(xf * triangles)

	return out


static func span(tris: PackedVector3Array) -> Vector2:
	var low := INF
	var high := -INF
	for v in tris:
		low = minf(low, v.y)
		high = maxf(high, v.y)

	return Vector2(low, high)


static func build(tris: PackedVector3Array, centre: float, half: float, start: float, width: float, gap: float) -> ArrayMesh:
	var step := 2.0 * half / float(ROWS)
	var gap_y := step * 0.5
	var first := centre - half - gap_y
	var planes: Array[PackedVector2Array] = []
	for k in 2 * ROWS + 3:
		planes.append(PackedVector2Array())

	_slice(tris, first, gap_y, planes)

	var hulls: Array[PackedVector2Array] = []
	var heights := PackedFloat32Array()
	for j in ROWS + 1:
		heights.append(centre - half + step * float(j))
		var points := planes[2 * j]
		points.append_array(planes[2 * j + 1])
		points.append_array(planes[2 * j + 2])
		hulls.append(Geometry2D.convex_hull(points))

	for j in ROWS + 1:
		if hulls[j].size() < 4:
			hulls[j] = _nearest(hulls, j)

	var rings: Array[PackedVector3Array] = []
	for j in ROWS + 1:
		var hull := hulls[j]
		var middle := Vector2.ZERO
		for p in hull:
			middle += p

		middle /= float(hull.size())

		var thick := gap * (0.45 + 0.55 * sin(PI * float(j) / float(ROWS)))
		var ring := PackedVector3Array()
		for i in COLUMNS + 1:
			var theta := start + width * float(i) / float(COLUMNS)
			var dir := Vector2(sin(theta), -cos(theta))
			var r := _reach(hull, middle, dir) + thick
			ring.append(Vector3(middle.x + dir.x * r, heights[j], middle.y + dir.y * r))

		rings.append(ring)

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for j in ROWS + 1:
		for i in COLUMNS + 1:
			var theta := start + width * float(i) / float(COLUMNS)
			vertices.append(rings[j][i])
			normals.append(Vector3(sin(theta), 0.0, -cos(theta)))
			uvs.append(Vector2(float(i) / float(COLUMNS), float(j) / float(ROWS)))

	var indices := PackedInt32Array()
	var row := COLUMNS + 1
	for j in ROWS:
		for i in COLUMNS:
			var at := j * row + i
			indices.append_array([at, at + 1, at + row + 1, at, at + row + 1, at + row])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _slice(tris: PackedVector3Array, first: float, gap: float, planes: Array[PackedVector2Array]) -> void:
	var last := planes.size() - 1
	for t in range(0, tris.size(), 3):
		var a := tris[t]
		var b := tris[t + 1]
		var c := tris[t + 2]
		var low := minf(a.y, minf(b.y, c.y))
		var high := maxf(a.y, maxf(b.y, c.y))
		var k0 := maxi(ceili((low - first) / gap), 0)
		var k1 := mini(floori((high - first) / gap), last)
		for k in range(k0, k1 + 1):
			var y := first + gap * float(k)
			_cross(a, b, y, planes[k])
			_cross(b, c, y, planes[k])
			_cross(c, a, y, planes[k])


static func _cross(p: Vector3, q: Vector3, y: float, out: PackedVector2Array) -> void:
	if (p.y - y) * (q.y - y) < 0.0:
		var k := (y - p.y) / (q.y - p.y)
		out.append(Vector2(p.x + (q.x - p.x) * k, p.z + (q.z - p.z) * k))


static func _nearest(hulls: Array[PackedVector2Array], row: int) -> PackedVector2Array:
	for d in range(1, hulls.size()):
		for j in [row - d, row + d]:
			if j >= 0 and j < hulls.size() and hulls[j].size() >= 4:
				return hulls[j]

	return hulls[row]


static func _reach(hull: PackedVector2Array, middle: Vector2, dir: Vector2) -> float:
	var best := 0.0
	for i in hull.size():
		var a := hull[i] - middle
		var b := hull[(i + 1) % hull.size()] - middle
		var edge := b - a
		var denom := dir.cross(edge)
		if absf(denom) < 0.000001:
			continue

		var t := a.cross(edge) / denom
		var s := a.cross(dir) / denom
		if t > 0.0 and s >= 0.0 and s <= 1.0:
			best = maxf(best, t)

	return best
