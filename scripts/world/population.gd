class_name Population
extends RefCounted

const SNIPER_SHARE := 0.1
const SNIPER_MIN_CHUNKS := 3
const SNIPER := preload("res://scenes/weapons/l96a1_stats.tres")

const GUNS := [
	preload("res://scenes/weapons/g17_stats.tres"),
	preload("res://scenes/weapons/m4a1_stats.tres"),
	preload("res://scenes/weapons/rem870_stats.tres"),
]

const GUN_WEIGHTS := {
	LevelSettings.Difficulty.EASY: [0.7, 0.2, 0.1],
	LevelSettings.Difficulty.NORMAL: [0.45, 0.35, 0.2],
	LevelSettings.Difficulty.HARD: [0.25, 0.45, 0.3],
}


static func fill(chunks: Array[Chunk], settings: LevelSettings, rng: RandomNumberGenerator) -> void:
	var populated: Array[Chunk] = []
	for chunk in chunks:
		if chunk.role == Chunk.Role.START:
			_clear(chunk.spawns(), [])
		else:
			populated.append(chunk)

	var capacity := 0
	for chunk in populated:
		capacity += mini(settings.enemies_per_chunk, _of_role(chunk, ChunkSpawn.Role.ANY).size())

	var snipers := roundi(capacity * SNIPER_SHARE)
	if settings.chunk_count >= SNIPER_MIN_CHUNKS:
		snipers = maxi(snipers, 1)

	var perched: Array[Chunk] = []
	for chunk in _shuffled(populated, rng):
		if perched.size() < snipers and not _of_role(chunk, ChunkSpawn.Role.SNIPER).is_empty():
			perched.append(chunk)

	var skill: Vector2 = LevelSettings.SKILL[settings.difficulty]
	for chunk in populated:
		var keep: Array[ChunkSpawn] = []
		var want := settings.enemies_per_chunk
		if chunk in perched and want > 0:
			var perch := _shuffled(_of_role(chunk, ChunkSpawn.Role.SNIPER), rng)[0] as ChunkSpawn
			perch.archetype = EnemyTraits.Archetype.MARKSMAN
			perch.weapon = SNIPER
			keep.append(perch)
			want -= 1

		for spawn in _shuffled(_of_role(chunk, ChunkSpawn.Role.ANY), rng).slice(0, want):
			spawn.archetype = EnemyTraits.Archetype.AUTO
			spawn.weapon = _gun(settings.difficulty, rng)
			keep.append(spawn)

		for spawn in keep:
			spawn.skill_range = skill
			spawn.hostile = not settings.peaceful_enemies
			spawn.random_seed = rng.randi_range(1, 0x7fffffff)

		_clear(chunk.spawns(), keep)


static func _gun(difficulty: LevelSettings.Difficulty, rng: RandomNumberGenerator) -> WeaponStats:
	var weights: Array = GUN_WEIGHTS[difficulty]
	var pick := rng.randf()
	for i in GUNS.size():
		pick -= weights[i]
		if pick <= 0.0:
			return GUNS[i]

	return GUNS[0]


static func _of_role(chunk: Chunk, role: ChunkSpawn.Role) -> Array[ChunkSpawn]:
	var found: Array[ChunkSpawn] = []
	for spawn in chunk.spawns():
		if spawn.role == role:
			found.append(spawn)

	return found


static func _clear(all: Array[ChunkSpawn], keep: Array) -> void:
	for spawn in all:
		if spawn not in keep:
			spawn.get_parent().remove_child(spawn)
			spawn.free()


static func _shuffled(items: Array, rng: RandomNumberGenerator) -> Array:
	var out := items.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = out[i]
		out[i] = out[j]
		out[j] = swap

	return out
