class_name StreetChunk
extends Chunk

const TILE := 6.0
const ROAD := -7.0

@export var tiles := Vector2i(3, 5)
@export var planters := Vector2i(2, 4)

var _width := 0.0
var _cover: Array[float] = []
var _rng: RandomNumberGenerator
var _geometry: Node3D
var _enemies: Node3D
var _batch := Batch.new()
var _sway := Sway.new()


func build(rng: RandomNumberGenerator) -> void:
	_rng = rng
	_geometry = $Geometry
	_enemies = $Enemies

	var count := rng.randi_range(tiles.x, tiles.y)
	_width = TILE * count
	$Exit.position.x = _width
	Kit.solid(_geometry, Vector3(_width, 1.0, 4.0), Vector3(_width * 0.5, -0.5, 0.0), &"concrete")

	_batch.pavement(_width)
	for i in count:
		_batch.urban("decals/decal_brokenline_straight", Vector3(TILE * i + TILE * 0.5, 0.0, ROAD))

	_crossings()
	_pavement_life()
	_far_side()
	_edges()
	_enemies_on_street()
	_batch.commit(_geometry)
	add_child(_sway)


func _crossings() -> void:
	if _width >= 18.0 and _rng.randf() < 0.6:
		_batch.urban("decals/decal_crosswalk", Vector3(_rng.randf_range(4.0, _width - 4.0), 0.0, ROAD), PI * 0.5)


func _pavement_life() -> void:
	for i in _rng.randi_range(planters.x, planters.y):
		var x := _rng.randf_range(3.0, _width - 3.0)
		if _clear(x):
			_cover.append(x)
			Kit.urban(_geometry, "props/prop_planter_single", Vector3(x, 0.0, 0.0), PI * 0.5)
			Kit.solid(_geometry, Vector3(2.0, 0.6, 1.6), Vector3(x, 0.3, 0.0), &"concrete")

	var x := _rng.randf_range(1.5, 4.0)
	while x < _width - 1.5:
		_tree(Vector3(x, 0.0, -2.6), _rng.randf_range(0.7, 1.0), true)
		x += _rng.randf_range(4.0, 8.0)

	_batch.scatter(Kit.SHRUBS, _rng, int(_width / 6.0) + 1, Vector2(1.0, _width - 1.0), Vector2(-1.9, -1.1), Vector2(0.5, 0.8))
	_batch.scatter(Kit.TUFTS, _rng, int(_width / 2.0), Vector2(1.0, _width - 1.0), Vector2(-3.8, -1.1), Vector2(0.4, 0.7))
	for i in int(_width / 6.0):
		_batch.urban("props/prop_bollard", Vector3(i * 6.0 + 3.0, 0.0, -1.35))

	for i in int(_width / 12.0):
		_batch.urban("props/prop_manholecover", Vector3(_rng.randf_range(2.0, _width - 2.0), -0.14, -5.6 - _rng.randf() * 4.0))


func _far_side() -> void:
	var x := _rng.randf_range(1.0, 5.0)
	while x < _width - 1.0:
		_tree(Vector3(x, 0.0, -11.2), _rng.randf_range(1.1, 1.6), false)
		x += _rng.randf_range(6.0, 12.0)


func _tree(at: Vector3, size: float, pit: bool) -> void:
	if pit:
		_batch.urban("sidewalks/sidewalk_planter", at, 0.0)

	var tree := Kit.nature(_geometry, Kit.TREES[_rng.randi_range(0, Kit.TREES.size() - 1)], at, _rng.randf() * TAU, Vector3.ONE * size)
	_sway.add(tree)


func _clear(x: float) -> bool:
	return _cover.all(func(other: float) -> bool: return absf(x - other) > 3.5)


func _edges() -> void:
	if role == Role.START:
		Kit.solid(_geometry, Vector3(0.4, 8.0, 4.0), Vector3(-0.2, 4.0, 0.0), &"concrete")
		_boundary(-1.3)

	if role == Role.END:
		Kit.solid(_geometry, Vector3(0.4, 8.0, 4.0), Vector3(_width + 0.2, 4.0, 0.0), &"concrete")
		_boundary(_width + 1.3)
		var objective := Marker3D.new()
		objective.name = "Objective"
		objective.position = Vector3(_width - 3.0, 0.0, 0.0)
		add_child(objective)


func _boundary(x: float) -> void:
	for z in [-3.0, -1.0, 1.0, 3.0]:
		Kit.urban(_geometry, "props/prop_planter_single", Vector3(x, 0.0, z), PI * 0.5)

	_tree(Vector3(x, 0.0, -2.0), 1.1, false)
	_tree(Vector3(x, 0.0, 2.0), 1.0, false)


func _enemies_on_street() -> void:
	if role == Role.START:
		return

	for i in _rng.randi_range(2, 4):
		var spawn := ChunkSpawn.new()
		spawn.position = Vector3(_free_spot(), 0.05, 0.0)
		spawn.rotation.y = -PI * 0.5
		spawn.name = "Spawn_%d" % i
		_enemies.add_child(spawn)


func _free_spot() -> float:
	for _try in 12:
		var x := _rng.randf_range(2.0, _width - 1.0)
		if _cover.all(func(other: float) -> bool: return x < other - 1.3 or x > other + 1.3):
			return x

	return 1.5
