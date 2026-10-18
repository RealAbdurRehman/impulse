class_name EnemyCover
extends RefCounted
## Finds spots for an enemy to fight from, out of the spots EnemyNav knows:
## cover to hide behind (a crouched enemy can't be hit there, but standing up it
## can shoot over it) and flanking positions (a clear view of the target from
## its other side or from higher up, reached by a route that doesn't go through
## the target). Spots already taken by another enemy are skipped.

## Standing and crouched heights of the eye, chest and hips, and of a muzzle.
const EYE := 1.5
const CROUCH_EYE := 1.1
const CHEST := 1.2
const CROUCH_CHEST := 0.85
const CROUCH_HIPS := 0.6
const MUZZLE := 1.45

## Cover only counts when what hides the enemy is this close to it (metres).
const MAX_COVER_GAP := 2.0

## Spots claimed so far: owner instance id -> position.
static var claims := { }

var nav: EnemyNav
var senses: EnemySenses
var rng: RandomNumberGenerator


static func claim(owner_id: int, at: Vector2) -> void:
	claims[owner_id] = at


static func release(owner_id: int) -> void:
	claims.erase(owner_id)


## How far the cover is from `at` (metres from the spot to the nearest thing
## that blocks the view of the threat) when a crouched enemy there can't be hit from where the threat stands;
## INF when it can be.
func cover_distance(at: Vector2, threat: Vector3) -> float:
	var worst := 0.0
	var eyes: Array[float] = [EYE, CROUCH_EYE]
	for eye in eyes:
		var from := Vector3(threat.x, threat.y + eye, 0.0)
		for height in [CROUCH_CHEST, CROUCH_HIPS]:
			var to := Vector3(at.x, at.y + height, 0.0)
			var stop := senses.blocker(to, from)
			if stop == Vector3.INF:
				return INF

			worst = maxf(worst, stop.distance_to(to))

	return worst


## A crouched enemy at `at` can't be hit from where the threat stands.
func hides(at: Vector2, threat: Vector3) -> bool:
	return cover_distance(at, threat) < INF


## Standing at `at` the enemy has a clear shot at the threat's chest.
func shoots(at: Vector2, threat: Vector3) -> bool:
	return senses.sees(Vector3(at.x, at.y + MUZZLE, 0.0), Vector3(threat.x, threat.y + CHEST, 0.0))


## The best cover within `search` metres by route, or Vector2(NAN, NAN). The
## search is for a spot where it hides and can still shoot over the top.
func find_cover(me: Vector3, threat: Vector3, owner_id: int, search: float, band: Vector2) -> Vector2:
	var best := Vector2(NAN, NAN)
	var best_score := INF
	var from_id := nav.nearest(me.x, me.y)
	var scored: Array = []

	for id in nav.spots_between(me.x - search, me.x + search):
		var at := Vector2(nav.xs[id], nav.ys[id])
		var distance := absf(at.x - threat.x)
		var same_side := signf(at.x - threat.x) == signf(me.x - threat.x)
		if absf(at.y - me.y) > 3.0 or distance < band.x * 0.6 or distance > band.y * 1.8 or not same_side or _taken(at, owner_id):
			continue

		scored.append([absf(at.x - me.x) + absf(at.y - me.y) * 2.0, id])

	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])

	var checked := 0
	for entry: Array in scored:
		if checked >= 14:
			break

		var id: int = entry[1]
		var at := Vector2(nav.xs[id], nav.ys[id])
		var near := cover_distance(at, threat)
		if near > MAX_COVER_GAP or not shoots(at, threat):
			continue

		checked += 1
		var path := nav.route(from_id, id, threat.x, 1.4, threat.y)
		if path.is_empty() and from_id != id:
			continue

		var distance := absf(at.x - threat.x)
		var mid := (band.x + band.y) * 0.5
		var score := nav.length(path, me.x) + absf(distance - mid) * 0.4 + near * 3.0 + rng.randf() * 1.5
		if score < best_score:
			best_score = score
			best = at

	return best


## A position with a clear view of the threat from its other side, or from at
## least a floor higher, by a route that keeps well clear of it.
func find_flank(me: Vector3, threat: Vector3, owner_id: int, search: float, limit: float) -> Vector2:
	var best := Vector2(NAN, NAN)
	var best_score := INF
	var from_id := nav.nearest(me.x, me.y)
	var behind := signf(threat.x - me.x)
	var scored: Array = []

	for id in nav.spots_between(me.x - search, me.x + search):
		var at := Vector2(nav.xs[id], nav.ys[id])
		var side := signf(at.x - threat.x)
		var opposite := side == behind and absf(at.x - threat.x) >= 3.0
		var high := at.y - threat.y >= 1.5 and absf(at.x - threat.x) >= 3.0
		if not (opposite or high) or _taken(at, owner_id):
			continue

		scored.append([absf(at.x - me.x) + absf(at.y - me.y), id, high])

	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])

	var checked := 0
	for entry: Array in scored:
		if checked >= 10:
			break

		var id: int = entry[1]
		var at := Vector2(nav.xs[id], nav.ys[id])
		if not shoots(at, threat) or not senses.sees(Vector3(at.x, at.y + MUZZLE, 0.0), Vector3(threat.x, threat.y + CROUCH_EYE, 0.0)):
			continue

		checked += 1
		var path := nav.route(from_id, id, threat.x, 1.6, threat.y)
		if path.is_empty():
			continue

		var travel := nav.length(path, me.x)
		if travel > limit:
			continue

		var score := travel - (4.0 if entry[2] else 0.0) + rng.randf() * 2.0
		if score < best_score:
			best_score = score
			best = at

	return best


func _taken(at: Vector2, owner_id: int) -> bool:
	for id: int in claims.keys():
		if not is_instance_id_valid(id):
			claims.erase(id)
		elif id != owner_id and (claims[id] as Vector2).distance_to(at) < 1.1:
			return true

	return false
