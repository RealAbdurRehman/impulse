class_name BuildingChunk
extends Chunk

enum Wall { NONE, SOLID, DOOR }

const STAIR_LINK := preload("res://scenes/world/stair_link.tscn")
const BAY := 4.0
const STOREY := 3.3
const SLAB := 0.3
const TILE := 0.1
const WALL := 0.2
const LANE := 2.0
const BACK := 2.2
const OPENING := 0.5
const DOOR_HEIGHT := 2.2
const FOOT := 1.7
const RUN := 4.4
const STEPS := 16
const WELL := 2.6
const CLIMB := 0.25
const FOOT_LINK := 1.25
const TOP_LINK := 6.6

@export var bays := Vector2i(3, 5)
@export var floors := Vector2i(1, 3)

var _width := 0.0
var _bay_count := 0
var _floor_count := 0
var _rooms: Array[float] = []
var _walls := { }
var _rng: RandomNumberGenerator
var _batch := Batch.new()
var _geometry: Node3D
var _enemies: Node3D


func build(rng: RandomNumberGenerator) -> void:
	_rng = rng
	_geometry = $Geometry
	_enemies = $Enemies

	_bay_count = rng.randi_range(bays.x, bays.y)
	var most := mini(floors.y, 1 + floori(_bay_count * 0.5))
	_floor_count = rng.randi_range(mini(floors.x, most), most)
	_width = BAY * _bay_count
	$Exit.position.x = _width

	_plan()
	_batch.frontage(_width)
	Kit.solid(_geometry, Vector3(_width + 2.0, 1.0, LANE * 2.0), Vector3(_width * 0.5, -0.5, 0.0), &"concrete")
	for storey in _floor_count + 1:
		_slab(storey)

	for storey in _floor_count:
		_back_wall(storey)
		for i in _bay_count + 1:
			_wall(i, storey, _walls[Vector2i(i, storey)])

	for room in _rooms.size():
		_stairs(room)

	_batch.commit(_geometry)
	_furnish()


func _plan() -> void:
	var spare := _bay_count - 2 * (_floor_count - 1)
	var bay := 0
	for _room in _floor_count - 1:
		_rooms.append(bay * BAY)
		var extra := _rng.randi_range(0, spare)
		spare -= extra
		bay += 2 + extra

	for storey in _floor_count:
		for i in _bay_count + 1:
			var kind := Wall.DOOR if _rng.randf() < 0.55 else Wall.NONE
			if i == 0 or i == _bay_count:
				kind = Wall.DOOR if storey == 0 else Wall.SOLID

			_walls[Vector2i(i, storey)] = kind

	for room in _rooms.size():
		var middle := int(_rooms[room] / BAY) + 1
		_walls[Vector2i(middle, room)] = Wall.NONE
		_walls[Vector2i(middle, room + 1)] = Wall.NONE


func _has_well(storey: int) -> bool:
	return storey > 0 and storey <= _rooms.size()


func _well(storey: int) -> Vector2:
	var left := _rooms[storey - 1]
	return Vector2(left + WELL, left + FOOT + RUN)


func _spans(storey: int) -> Array[Vector2]:
	if not _has_well(storey):
		return [Vector2(0.0, _width)]

	var well := _well(storey)
	return [Vector2(0.0, well.x), Vector2(well.y, _width)]


func _slab(storey: int) -> void:
	var y := STOREY * storey
	var roof := storey == _floor_count
	var thick := SLAB if roof else SLAB - TILE
	for span in _spans(storey):
		var length := span.y - span.x
		var middle := (span.x + span.y) * 0.5
		Kit.concrete(_geometry, Vector3(length, thick, LANE + BACK), Vector3(middle, y - SLAB + thick * 0.5, (LANE - BACK) * 0.5))
		if storey > 0:
			Kit.solid(_geometry, Vector3(length, SLAB, LANE * 2.0), Vector3(middle, y - SLAB * 0.5, 0.0), &"concrete")

		if not roof:
			_tiles(span, y)

	if _has_well(storey):
		var well := _well(storey)
		Kit.concrete(_geometry, Vector3(well.y - well.x, SLAB, WALL), Vector3((well.x + well.y) * 0.5, y - SLAB * 0.5, -BACK + WALL * 0.5))


func _tiles(span: Vector2, y: float) -> void:
	var x := span.x
	while x < span.y - 0.001:
		var length := minf(2.0, span.y - x)
		for z in [-1.0, 1.0]:
			_batch.urban("floors/floor_2x2", Vector3(x + length * 0.5, y, z), 0.0, Vector3(length * 0.5, 1.0, 1.0))

		x += length


func _back_wall(storey: int) -> void:
	var y := STOREY * storey
	Kit.solid(_geometry, Vector3(_width, STOREY - SLAB, WALL), Vector3(_width * 0.5, y + (STOREY - SLAB) * 0.5, -BACK + WALL * 0.5), &"brick")
	for i in _bay_count * 2:
		var piece := "walls/brick/brick_plain_3"
		if _rng.randf() < 0.3:
			piece = "walls/brick/brick_window_square_single"

		_batch.urban(piece, Vector3(i * 2.0 + 1.0, y, -BACK), PI)


func _wall(index: int, storey: int, kind: Wall) -> void:
	if kind == Wall.NONE:
		return

	var y := STOREY * storey
	var height := STOREY - SLAB
	var yaw := -PI * 0.5 if index == 0 else PI * 0.5
	var centre := WALL * 0.5 if index == 0 else _width - WALL * 0.5 if index == _bay_count else index * BAY
	var origin := centre + WALL * 0.5 * signf(yaw)

	if kind == Wall.SOLID:
		Kit.solid(_geometry, Vector3(WALL, height, LANE * 2.0), Vector3(centre, y + height * 0.5, 0.0), &"brick")
		for z in [-1.0, 1.0]:
			_batch.urban("walls/brick/brick_plain_3", Vector3(origin, y, z), yaw)

		return

	var side := LANE - OPENING
	for z in [-(OPENING + side * 0.5), OPENING + side * 0.5]:
		Kit.solid(_geometry, Vector3(WALL, height, side), Vector3(centre, y + height * 0.5, z), &"brick")

	var lintel := height - DOOR_HEIGHT
	Kit.solid(_geometry, Vector3(WALL, lintel, OPENING * 2.0), Vector3(centre, y + DOOR_HEIGHT + lintel * 0.5, 0.0), &"brick")
	_batch.urban("doors/doorframe_metal_single", Vector3(origin, y, 0.0), yaw)
	for z in [-1.5, 1.5]:
		_batch.urban("walls/brick/brick_plain_3", Vector3(origin, y, z), yaw, Vector3(0.5, 1.0, 1.0))

	var door := Door.new()
	door.position = Vector3(centre, y, -door.width * 0.5)
	door.rotation.y = -PI * 0.5
	_geometry.add_child(door)


func _stairs(room: int) -> void:
	var left := _rooms[room]
	var y := STOREY * room
	var origin := Vector3(left + FOOT, y, 0.0)
	Kit.staircase(_geometry, origin, RUN, STOREY, STEPS, -CLIMB, -LANE)
	Kit.handrail(_geometry, Vector3(left + FOOT, y, -CLIMB + 0.03), Vector3(left + FOOT + RUN, y + STOREY, -CLIMB + 0.03))

	var steps := Kit.steps(_geometry, origin, RUN, STOREY, STEPS, -CLIMB, -LANE)
	steps.collision_layer = 0
	_link(Vector3(left + FOOT_LINK, y, 0.0), left + TOP_LINK, steps)
	_link(Vector3(left + TOP_LINK, y + STOREY, 0.0), left + FOOT_LINK, steps)


func _link(at: Vector3, goal: float, steps: StaticBody3D) -> void:
	var link := STAIR_LINK.instantiate() as StairLink
	link.position = at
	link.goal = goal
	link.steps = steps
	_geometry.add_child(link)


func _blocked(storey: int) -> Array[Vector2]:
	var found: Array[Vector2] = []
	for room in _rooms.size():
		var left := _rooms[room]
		if storey == room:
			found.append(Vector2(left + FOOT - 0.4, left + FOOT + RUN + 0.4))

		if storey == room + 1:
			found.append(Vector2(left + WELL - 0.4, left + FOOT + RUN + 0.2))

	return found


func _open(from: float, to: float, storey: int) -> bool:
	return _blocked(storey).all(func(span: Vector2) -> bool: return to < span.x or from > span.y)


func _standable(x: float, storey: int) -> bool:
	return _open(x, x, storey)


func _furnish() -> void:
	for storey in _floor_count:
		var y := STOREY * storey
		for bay in range(0, _bay_count, 2):
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(bay * BAY + BAY, y + 2.4, 1.0)
			lamp.omni_range = 9.0
			lamp.light_energy = 0.9
			lamp.light_color = Color(1.0, 0.9, 0.75)
			_geometry.add_child(lamp)

		for bay in _bay_count:
			var x := bay * BAY + _rng.randf_range(1.0, 3.0)
			var facing := -PI * 0.5 if _rng.randf() < 0.75 else PI * 0.5
			if (storey == 0 and bay == 0) or not _standable(x, storey):
				continue

			var spawn := ChunkSpawn.new()
			spawn.position = Vector3(x, y + 0.05, 0.0)
			spawn.rotation.y = facing
			spawn.name = "Spawn_%d_%d" % [storey, bay]
			_enemies.add_child(spawn)

	var top := _floor_count - 1
	var perch_x := _width - 1.2
	if not _standable(perch_x, top):
		perch_x = _width - 0.7

	var perch := ChunkSpawn.new()
	perch.role = ChunkSpawn.Role.SNIPER
	perch.position = Vector3(perch_x, STOREY * top + 0.05, 0.0)
	perch.rotation.y = -PI * 0.5
	perch.name = "Perch"
	_enemies.add_child(perch)
