class_name EnemyNav
extends RefCounted

enum Kind { WALK, JUMP, DROP }

const STEP := 0.25
const TOP := 14.0
const BOTTOM := -10.0
const MAX_STEP := 0.52
const EPS := 0.01
const JUMP_UP := 0.9
const JUMP_GAP := 1.7
const MAX_DROP := 4.0
const WALL_TOP := 1.4
const WALL_REACH := 4.5
const WALL_LIMIT := 3.15
const BIG_DROP := 2.5
const BIG_DROP_COST := 16.0
const NUDGE := 0.06
const ROOM_LIFT := 0.625
const ROOM_HEIGHT := 1.15
const ROOF_CHECK := 0.45
const MIN_LAYER := 0.5
const DOOR_REACH := 0.35

static var _maps := { }

var xs := PackedFloat32Array()
var ys := PackedFloat32Array()
var links: Array = []

var _first := 0.0
var _columns: Array = []
var _space: PhysicsDirectSpaceState3D
var _mask := 1
var _z := 0.0
var _body := BoxShape3D.new()


static func reset() -> void:
	_maps.clear()


static func of(node: Node3D, mask: int, extent: float) -> EnemyNav:
	var key := node.get_world_3d().get_rid()
	if not _maps.has(key):
		var doors: Array[Vector3] = []
		for prop in node.get_tree().get_nodes_in_group(&"props"):
			if prop is Door:
				doors.append((prop as Door).global_position)

		var nav := EnemyNav.new()
		nav._build(node.get_world_3d().direct_space_state, mask, node.global_position, extent, doors)
		_maps[key] = nav

	return _maps[key]


func nearest(x: float, y: float, reach := 1.2) -> int:
	var column := roundi((x - _first) / STEP)
	for spread in [0, 1, 2]:
		var best := -1
		var best_dy := reach
		for c in [column - spread, column + spread]:
			if c < 0 or c >= _columns.size():
				continue

			for id: int in _columns[c]:
				var dy := absf(ys[id] - y)
				if dy < best_dy:
					best_dy = dy
					best = id

		if best >= 0:
			return best

	return -1


func spots_between(from_x: float, to_x: float) -> PackedInt32Array:
	var found := PackedInt32Array()
	var a := maxi(roundi((minf(from_x, to_x) - _first) / STEP), 0)
	var b := mini(roundi((maxf(from_x, to_x) - _first) / STEP), _columns.size() - 1)
	for c in range(a, b + 1):
		found.append_array(_columns[c])

	return found


func route(from_id: int, to_id: int, avoid_x := 0.0, avoid_radius := 0.0, avoid_y := 0.0) -> PackedVector3Array:
	var path := PackedVector3Array()
	if from_id < 0 or to_id < 0:
		return path

	var best := { from_id: 0.0 }
	var came := { }
	var open := [[_estimate(from_id, to_id), from_id]]
	while not open.is_empty():
		var current: int = _pop(open)
		if current == to_id:
			break

		for link: Array in links[current]:
			var next: int = link[0]
			if avoid_radius > 0.0 and absf(xs[next] - avoid_x) < avoid_radius and absf(ys[next] - avoid_y) < 1.2:
				continue

			var cost: float = best[current] + link[2]
			if not best.has(next) or cost < best[next]:
				best[next] = cost
				came[next] = [current, link[1]]
				_push(open, [cost + _estimate(next, to_id), next])

	if not came.has(to_id) and from_id != to_id:
		return path

	var walk: Array[Vector3] = []
	var at := to_id
	while at != from_id:
		var step: Array = came[at]
		walk.append(Vector3(xs[at], ys[at], float(step[1])))
		at = step[0]

	walk.reverse()
	path.append_array(PackedVector3Array(walk))
	return path


func length(path: PackedVector3Array, from_x: float) -> float:
	var total := 0.0
	var x := from_x
	for point in path:
		total += absf(point.x - x) + _extra(int(point.z))
		x = point.x

	return total


func _extra(kind: int) -> float:
	return 1.5 if kind != Kind.WALK else 0.0


func _estimate(a: int, b: int) -> float:
	return absf(xs[a] - xs[b])


func _push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		var parent := (i - 1) >> 1
		if (heap[parent] as Array)[0] <= item[0]:
			break

		heap[i] = heap[parent]
		i = parent

	heap[i] = item


func _pop(heap: Array) -> int:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if not heap.is_empty():
		var i := 0
		while true:
			var child := 2 * i + 1
			if child >= heap.size():
				break

			if child + 1 < heap.size() and (heap[child + 1] as Array)[0] < (heap[child] as Array)[0]:
				child += 1

			if (heap[child] as Array)[0] >= last[0]:
				break

			heap[i] = heap[child]
			i = child

		heap[i] = last

	return top[1]


func _build(space: PhysicsDirectSpaceState3D, mask: int, centre: Vector3, extent: float, doors: Array[Vector3]) -> void:
	_space = space
	_mask = mask
	_z = centre.z
	_body.size = Vector3(0.06, ROOM_HEIGHT, 0.3)
	_first = snappedf(centre.x - extent, STEP) + 0.07

	var count := int(extent * 2.0 / STEP) + 1
	for c in count:
		var found: Array[int] = []
		var x := _first + float(c) * STEP
		var y := TOP
		while y > BOTTOM:
			var hit := _down(x, y)
			if hit.is_empty():
				break

			var top: float = (hit.position as Vector3).y
			if (hit.normal as Vector3).y > 0.6 and _room(x, top) and (found.is_empty() or ys[found[-1]] - top >= MIN_LAYER):
				xs.append(x)
				ys.append(top)
				links.append([])
				found.append(xs.size() - 1)

			y = top - 0.1

		_columns.append(found)

	for id in xs.size():
		_link(id)

	for door in doors:
		_bridge(door)


func _bridge(door: Vector3) -> void:
	var near := nearest(door.x - DOOR_REACH, door.y)
	var far := nearest(door.x + DOOR_REACH, door.y)
	if near >= 0 and far >= 0 and near != far:
		_add(near, far, Kind.WALK, DOOR_REACH * 2.0)
		_add(far, near, Kind.WALK, DOOR_REACH * 2.0)


func _link(id: int) -> void:
	var column := roundi((xs[id] - _first) / STEP)
	var y := ys[id]
	for dir in [-1, 1]:
		var next_column: int = column + dir
		if next_column < 0 or next_column >= _columns.size():
			continue

		var landing := -1
		var ground_beside := false
		var wall_ahead := false
		for other: int in _columns[next_column]:
			var dy := ys[other] - y
			if dy > JUMP_UP + EPS and dy < WALL_REACH:
				wall_ahead = true

			if absf(dy) <= MAX_STEP + EPS:
				_add(id, other, Kind.WALK, STEP + absf(dy) * 0.5)
			elif dy > MAX_STEP and dy <= JUMP_UP + EPS:
				_add(id, other, Kind.JUMP, STEP + 1.5 + dy)

			if dy >= -MAX_STEP - EPS and dy <= JUMP_UP:
				ground_beside = true
			elif dy < -MAX_STEP and dy >= -MAX_DROP and (landing < 0 or ys[other] > ys[landing]):
				landing = other

		if ground_beside or wall_ahead:
			landing = -1

		if landing < 0 and not wall_ahead and _gap_between(column, column + dir * 2, y) and next_column + dir < _columns.size() and next_column + dir >= 0:
			for other: int in _columns[next_column + dir]:
				var dy := ys[other] - y
				if dy < -MAX_STEP and dy >= -MAX_DROP and (landing < 0 or ys[other] > ys[landing]):
					landing = other

		if landing >= 0:
			var fall := y - ys[landing]
			_add(id, landing, Kind.DROP, STEP + 1.0 + fall * 0.5 + (BIG_DROP_COST if fall > BIG_DROP else 0.0))

		for reach in range(2, int(JUMP_GAP / STEP) + 1):
			var far: int = column + dir * reach
			if far < 0 or far >= _columns.size():
				break

			for other: int in _columns[far]:
				var rise := ys[other] - y
				var dy := absf(rise)
				var small_hole := reach == 2 and (dy <= MAX_STEP + EPS or (rise > 0.0 and rise <= JUMP_UP + EPS))
				if dy > 0.35 and not small_hole:
					continue

				if not _gap_between(column, far, y):
					continue

				if small_hole and dy <= MAX_STEP + EPS:
					_add(id, other, Kind.WALK, STEP * 2.0)
				elif small_hole and dy > 0.35:
					_add(id, other, Kind.JUMP, STEP * 2.0 + 1.5 + rise)
				else:
					_add(id, other, Kind.JUMP, STEP * float(reach) + 2.0)


func _gap_between(a: int, b: int, y: float) -> bool:
	for c in range(mini(a, b) + 1, maxi(a, b)):
		for other: int in _columns[c]:
			if ys[other] > y - 1.0 and ys[other] < y + WALL_LIMIT:
				return false

	return true


func _add(from_id: int, to_id: int, kind: int, cost: float) -> void:
	(links[from_id] as Array).append([to_id, kind, cost])


func _down(x: float, y: float) -> Dictionary:
	var hit := _ray(x, y)
	if hit.is_empty() or (hit.normal as Vector3).y > 0.6:
		return hit

	var best := hit
	for nudge in [-NUDGE, NUDGE]:
		var near := _ray(x + nudge, y)
		if near.is_empty() or (near.normal as Vector3).y <= 0.6:
			continue

		if best == hit or (near.position as Vector3).y > (best.position as Vector3).y:
			best = near

	return best


func _ray(x: float, y: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, y, _z), Vector3(x, BOTTOM, _z), _mask)
	return _space.intersect_ray(query)


func _room(x: float, y: float) -> bool:
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, y + 0.03, _z), Vector3(x, y + ROOF_CHECK, _z), _mask)
	return _space.intersect_ray(query).is_empty() and _empty(_body, Vector3(x, y + ROOM_LIFT + ROOM_HEIGHT * 0.5, _z))


func _empty(shape: Shape3D, at: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = _mask
	query.transform = Transform3D(Basis.IDENTITY, at)
	return _space.intersect_shape(query, 1).is_empty()
