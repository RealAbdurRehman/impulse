class_name EnemySenses
extends RefCounted
## What an enemy can tell about the world: whether there is a clear view of a
## point, and whether a shot at it would hit the target, a friend, or a wall.

enum Shot { CLEAR, WALL, ALLY }

const FAN: Array[float] = [0.0, 0.1, -0.1]
const TUBE := 0.3

var body: CharacterMovement
var health: Health

var _own: Array[RID] = []
var _linked := false


## Nothing solid between the two points (bodies of living characters don't block a view).
func sees(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, body.ground_mask)
	return body.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Where a line from `from` toward `to` is first blocked by the level, or Vector3.INF.
func blocker(from: Vector3, to: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(from, to, body.ground_mask)
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	return Vector3.INF if hit.is_empty() else hit.position


## What a bullet fired from `from` along `dir` (unit, in the play plane) would
## hit first within `reach`. Hitting the target's own Health counts as clear;
## anything else in front of it is a wall or a corpse (WALL), or a living
## friend (ALLY). Friends are looked for in a fat tube around the shot, because
## the muzzle climbs and the bullets spread, and close up a few degrees is a
## lot of body. Without friendly fire the bullets go through friends, so they
## are no problem and the view past them is what counts.
func shot(from: Vector3, dir: Vector3, reach: float, target: Health, friendly_fire := false) -> Shot:
	_link()

	if friendly_fire and _ally_in_tube(from, dir, reach, target):
		return Shot.ALLY

	var space := body.get_world_3d().direct_space_state
	for z in FAN:
		var query := PhysicsRayQueryParameters3D.create(
			from + Vector3(0.0, 0.0, z),
			from + dir * reach + Vector3(0.0, 0.0, z),
			body.ground_mask | Hitboxes.LAYER,
			_own,
		)
		query.collide_with_areas = true

		var hit := space.intersect_ray(query)
		var skipped := _own
		while not friendly_fire and not hit.is_empty() and _is_friend(hit.collider):
			if skipped.size() == _own.size():
				skipped = _own.duplicate()

			skipped.append(hit.rid)
			query.exclude = skipped
			hit = space.intersect_ray(query)

		if not hit.is_empty() and Health.of(hit.collider) != target:
			return Shot.WALL

	return Shot.CLEAR


func _is_friend(collider: Object) -> bool:
	var other := Health.of(collider)
	return other != null and other.team != &"" and other.team == health.team


## How far a line from `from` along `dir` goes (up to `reach`) before it meets the
## level or a body.
func beam(from: Vector3, dir: Vector3, reach: float) -> float:
	_link()
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * reach, body.ground_mask | Hitboxes.LAYER, _own)
	query.collide_with_areas = true

	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	return reach if hit.is_empty() else from.distance_to(hit.position)


func _ally_in_tube(from: Vector3, dir: Vector3, reach: float, target: Health) -> bool:
	var tube := CapsuleShape3D.new()
	tube.radius = TUBE
	tube.height = maxf(reach, TUBE * 2.0 + 0.01)

	var up := dir
	var across := Vector3.BACK
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = tube
	query.transform = Transform3D(Basis(up.cross(across).normalized(), up, across), from + dir * reach * 0.5)
	query.collision_mask = Hitboxes.LAYER
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.exclude = _own

	for result in body.get_world_3d().direct_space_state.intersect_shape(query, 16):
		var owner_health := Health.of(result.collider)
		if owner_health != null and owner_health != target and owner_health.alive:
			return true

	return false


func _link() -> void:
	if _linked:
		return

	_linked = true
	for bone in health.ragdoll.get_children():
		if bone is PhysicalBone3D:
			_own.append(bone.get_rid())
			for child in bone.get_children():
				if child is Area3D:
					_own.append(child.get_rid())
