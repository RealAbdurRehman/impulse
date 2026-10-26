class_name ParkChunk
extends Chunk

const TILE := 6.0

@export var tiles := Vector2i(2, 4)

var _width := 0.0
var _covers: Array[float] = []
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
	Kit.grass(_geometry, Vector3(_width, 0.3, 6.0), Vector3(_width * 0.5, -0.25, -7.0))
	_batch.pavement(_width)

	_planting()
	_path()
	_hedges()
	_cover()
	_batch.commit(_geometry)
	add_child(_sway)

	for i in rng.randi_range(2, 4):
		var spawn := ChunkSpawn.new()
		spawn.position = Vector3(_free_spot(), 0.05, 0.0)
		spawn.rotation.y = -PI * 0.5
		spawn.name = "Spawn_%d" % i
		_enemies.add_child(spawn)


func _planting() -> void:
	var x := _rng.randf_range(1.0, 3.0)
	while x < _width - 1.0:
		_tree(Vector3(x, 0.0, _rng.randf_range(-9.2, -5.0)), _rng.randf_range(0.9, 1.4))
		x += _rng.randf_range(2.5, 5.0)

	var along := Vector2(0.5, _width - 0.5)
	_batch.scatter(Kit.SHRUBS, _rng, int(_width / 1.6), along, Vector2(-4.9, -4.3), Vector2(0.6, 0.9))
	_batch.scatter(Kit.SHRUBS, _rng, int(_width / 3.0), along, Vector2(-9.6, -5.2), Vector2(0.5, 1.0))
	_batch.scatter(Kit.TUFTS, _rng, int(_width * 1.5), along, Vector2(-9.8, -4.2), Vector2(0.4, 0.8))
	_batch.scatter(Kit.TUFTS, _rng, int(_width / 3.0), along, Vector2(-1.4, -1.1), Vector2(0.4, 0.6))


func _path() -> void:
	var x := 1.0
	while x < _width - 1.0:
		_batch.nature("rocks/rockpath_round_wide", Vector3(x, 0.0, -6.8 + sin(x * 0.5) * 0.7), _rng.randf() * TAU, Vector3.ONE * 0.9)
		x += 1.7


func _cover() -> void:
	var x := _rng.randf_range(3.0, 6.0)
	while x < _width - 3.0:
		_covers.append(x)
		Kit.rock(_geometry, Kit.ROCKS[_rng.randi_range(0, Kit.ROCKS.size() - 1)], Vector3(x, 0.0, 0.0), _rng.randf() * TAU, _rng.randf_range(0.4, 0.5))
		x += _rng.randf_range(6.0, 10.0)

	for i in int(_width / 6.0):
		_batch.nature(Kit.ROCKS[_rng.randi_range(0, Kit.ROCKS.size() - 1)], Vector3(_rng.randf_range(1.0, _width - 1.0), 0.0, _rng.randf_range(-9.0, -5.5)), _rng.randf() * TAU, Vector3.ONE * _rng.randf_range(0.3, 0.7))


func _hedges() -> void:
	for x in [0.5, _width - 0.5]:
		_batch.scatter(Kit.SHRUBS, _rng, 7, Vector2(x - 0.4, x + 0.4), Vector2(-9.8, -4.5), Vector2(0.9, 1.3))
		_tree(Vector3(x, 0.0, _rng.randf_range(-8.0, -6.0)), _rng.randf_range(1.2, 1.5))


func _tree(at: Vector3, size: float) -> void:
	var tree := Kit.nature(_geometry, Kit.TREES[_rng.randi_range(0, Kit.TREES.size() - 1)], at, _rng.randf() * TAU, Vector3.ONE * size)
	_sway.add(tree)


func _free_spot() -> float:
	for _try in 12:
		var x := _rng.randf_range(2.0, _width - 2.0)
		if _covers.all(func(other: float) -> bool: return absf(x - other) > 1.5):
			return x

	return 1.2
