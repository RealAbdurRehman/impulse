class_name AttackTokens
extends RefCounted

const GRACE := 1.2
const REST := 0.7

static var limit := 3

static var _pools := { }


class Pool:
	var holders := { }
	var queue := { }
	var touched := { }
	var swept := 0.0


static func request(target_id: int, id: int, firing: bool) -> bool:
	if limit <= 0:
		return true

	var now := _now()
	var pool := _pool(target_id)
	_sweep(pool, now)
	pool.touched[id] = now

	if pool.holders.has(id):
		if firing:
			pool.holders[id] = now
		elif now - float(pool.holders[id]) > REST and not pool.queue.is_empty():
			pool.holders.erase(id)
			pool.queue[id] = true
			return false

		return true

	if pool.holders.size() < limit and (pool.queue.is_empty() or pool.queue.keys()[0] == id):
		pool.queue.erase(id)
		pool.holders[id] = now
		return true

	pool.queue[id] = true
	return false


static func release(id: int) -> void:
	for pool: Pool in _pools.values():
		_drop(pool, id)


static func holds(id: int) -> bool:
	for pool: Pool in _pools.values():
		if pool.holders.has(id):
			return true

	return false


static func count(target_id: int) -> int:
	return _pools[target_id].holders.size() if _pools.has(target_id) else 0


static func _pool(target_id: int) -> Pool:
	if not _pools.has(target_id):
		_pools[target_id] = Pool.new()

	return _pools[target_id]


static func _drop(pool: Pool, id: int) -> void:
	pool.holders.erase(id)
	pool.queue.erase(id)
	pool.touched.erase(id)


static func _sweep(pool: Pool, now: float) -> void:
	if now - pool.swept < 0.2:
		return

	pool.swept = now
	for id: int in pool.touched.keys():
		if now - float(pool.touched[id]) > GRACE:
			_drop(pool, id)


static func _now() -> float:
	return float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)
