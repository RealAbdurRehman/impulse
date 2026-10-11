class_name GripFit
extends RefCounted


class Solid:
	var mesh: TriangleMesh
	var to_gun := Transform3D.IDENTITY
	var to_mesh := Transform3D.IDENTITY


class Fit:
	var hole := Vector3.ZERO
	var fingers := Vector3.RIGHT
	var palm := Vector3.FORWARD
	var depth := 0.0
	var width := 0.0
	var outline := PackedVector2Array()


const SLICE := 0.01
const SLICES := 3
const WAIST := 2
const RAYS := 32
const FAR := 0.15

var _unit: float
var _solids: Array[Solid] = []


func _init(gun: Node3D, part: StringName) -> void:
	_unit = gun.scale.x
	for m in gun.get_node(NodePath(part)).find_children("*", "MeshInstance3D", true, false):
		var solid := Solid.new()
		solid.mesh = (m as MeshInstance3D).mesh.generate_triangle_mesh()
		solid.to_gun = local(m as Node3D, gun)
		solid.to_mesh = solid.to_gun.affine_inverse()
		_solids.append(solid)


static func local(node: Node3D, gun: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != gun:
		if n is Node3D:
			t = (n as Node3D).transform * t

		n = n.get_parent()

	return t


func fit(origin: Vector3, axis: Vector3, palm: Vector3, side: float) -> Fit:
	var at := origin
	var a := Vector3(axis.x, axis.y, 0.0).normalized()
	for i in 3:
		var line := _line(origin, a)
		at = line[0]
		a = line[1]

	var n := (palm - a * palm.dot(a)).normalized()
	var f := -side * a.cross(n)
	var points := _waist(at, a, f, n)
	var box := _box(points)
	var centre := box.get_center()

	var result := Fit.new()
	result.hole = at + f * centre.x + n * centre.y
	result.fingers = f
	result.palm = n
	result.depth = box.size.x
	result.width = box.size.y
	for p in points:
		result.outline.append(p - centre)

	return result


func _cast(from: Vector3, dir: Vector3) -> float:
	var best := INF
	for solid in _solids:
		var hit := solid.mesh.intersect_ray(
			solid.to_mesh * from,
			(solid.to_mesh.basis * dir).normalized(),
		)
		if not hit.is_empty():
			var point := solid.to_gun * (hit.position as Vector3)
			best = minf(best, point.distance_to(from))

	return best


func _section(at: Vector3, u: Vector3, w: Vector3) -> PackedVector2Array:
	var far := FAR / _unit
	var radii := PackedFloat32Array()
	for i in RAYS:
		var angle := TAU * float(i) / float(RAYS)
		var d := u * cos(angle) + w * sin(angle)
		var dist := _cast(at + d * far, -d)
		radii.append(far - dist if far - dist > 0.0 else -1.0)

	var points := PackedVector2Array()
	for i in RAYS:
		if radii[i] < 0.0:
			var before := i
			var after := i
			while radii[before % RAYS] < 0.0 and i - before < RAYS:
				before -= 1

			while radii[after % RAYS] < 0.0 and after - i < RAYS:
				after += 1

			if i - before >= RAYS:
				return PackedVector2Array()

			var k := float(i - before) / float(after - before)
			radii[i] = lerpf(radii[(before + RAYS) % RAYS], radii[after % RAYS], k)

		var angle := TAU * float(i) / float(RAYS)
		points.append(Vector2(cos(angle), sin(angle)) * radii[i])

	return points


func _box(points: PackedVector2Array) -> Rect2:
	var box := Rect2(points[0], Vector2.ZERO)
	for p in points:
		box = box.expand(p)

	return box


func _waist(at: Vector3, a: Vector3, u: Vector3, w: Vector3) -> PackedVector2Array:
	var span := SLICE / _unit
	var slices: Array[PackedVector2Array] = []
	for k in range(-WAIST, WAIST + 1):
		var points := _section(at + a * (float(k) * span), u, w)
		if not points.is_empty():
			slices.append(points)

	slices.sort_custom(
		func(x: PackedVector2Array, y: PackedVector2Array) -> bool:
			return _box(x).size.x < _box(y).size.x,
	)
	return slices[slices.size() >> 1]


func _line(at: Vector3, a: Vector3) -> PackedVector3Array:
	var span := SLICE / _unit
	var u := Vector3(a.y, -a.x, 0.0)

	var centers: Array[Vector3] = []
	var depths: Array[float] = []
	for k in range(-SLICES, SLICES + 1):
		var point := at + a * (float(k) * span)
		var points := _section(point, u, Vector3.BACK)
		if not points.is_empty():
			var box := _box(points)
			var mid := box.get_center()
			centers.append(point + u * mid.x + Vector3.BACK * mid.y)
			depths.append(box.size.x)

	var ordered := depths.duplicate()
	ordered.sort()
	var typical: float = ordered[ordered.size() >> 1]

	var mean := Vector3.ZERO
	var kept: Array[Vector3] = []
	for i in centers.size():
		if absf(depths[i] - typical) <= typical * 0.25:
			kept.append(centers[i])
			mean += centers[i]

	mean /= float(kept.size())

	var xx := 0.0
	var yy := 0.0
	var xy := 0.0
	for point in kept:
		var d := point - mean
		xx += d.x * d.x
		yy += d.y * d.y
		xy += d.x * d.y

	var angle := 0.5 * atan2(2.0 * xy, xx - yy)
	var line := Vector3(cos(angle), sin(angle), 0.0)
	if line.dot(a) < 0.0:
		line = -line

	return PackedVector3Array([mean + line * (at - mean).dot(line), line])
