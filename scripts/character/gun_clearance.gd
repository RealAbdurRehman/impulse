class_name GunClearance
extends RefCounted
## Keeps a gun out of bodies and walls. When the barrel would end up inside
## something it is pulled back toward the shoulder first (along the aim line it
## would have had), then raised (like a "high ready") until it clears. Both
## amounts ease in and out.

const PULLS: Array[float] = [0.0, 0.07, 0.14, 0.21, 0.28]
const LIFTS: Array[float] = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0, 1.2, 1.45]

## Raising the gun costs this much per radian, pulling it back per metre.
const LIFT_COST := 4.0
const PULL_COST := 6.0

var mask := 3
var half_height := 0.04

## The probe is a slab around the play plane, not the gun's own depth: from the
## side, a gun that touches a body in the plane should react even if it is held
## a few centimetres nearer the camera.
var half_depth := 0.2
var margin := 0.015

var attack := 18.0
var release := 5.0

## Once the gun has been moved out of the way it stays there at least this long,
## so a bobbing obstacle doesn't make the gun flutter.
var hold_time := 0.3

## What the hold solver applies: metres back along the barrel, radians of extra pitch.
var pull := 0.0
var lift := 0.0

var _shape := BoxShape3D.new()
var _query := PhysicsShapeQueryParameters3D.new()
var _order: Array[Vector2i] = []
var _goal := Vector2i.ZERO
var _hold := 0.0


func _init(ragdoll: PhysicalBoneSimulator3D) -> void:
	var own: Array[RID] = []
	for bone in ragdoll.get_children():
		if bone is PhysicalBone3D:
			own.append(bone.get_rid())

	_query.shape = _shape
	_query.collision_mask = mask
	_query.exclude = own

	for i in PULLS.size():
		for j in LIFTS.size():
			_order.append(Vector2i(i, j))

	_order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _cost(a) < _cost(b))


## stock: the gun's rear anchor in skeleton space with no pull applied. frames:
## the gun's orientation for each entry of LIFTS. barrel: stock to muzzle in gun axes.
func solve(
	space: PhysicsDirectSpaceState3D,
	to_world: Transform3D,
	plane_z: float,
	stock: Vector3,
	frames: Array[Basis],
	barrel: Vector3,
	dt: float,
) -> void:
	var length := barrel.length()
	var along := barrel / length
	var level := frames[0] * along
	_shape.size = Vector3(length + margin * 2.0, half_height * 2.0, half_depth * 2.0)

	var want := Vector2i(PULLS.size() - 1, LIFTS.size() - 1)
	for step in _order:
		var dir := frames[step.y] * along
		var centre := stock - level * PULLS[step.x] + dir * (length * 0.5)

		var flat := to_world.basis * dir
		flat = Vector3(flat.x, flat.y, 0.0).normalized()
		var at := to_world * centre
		at.z = plane_z

		_query.transform = Transform3D(Basis(flat, Vector3(-flat.y, flat.x, 0.0), Vector3.BACK), at)
		if space.intersect_shape(_query, 1).is_empty():
			want = step
			break

	if _cost(want) >= _cost(_goal):
		_goal = want
		_hold = hold_time
	elif _hold <= 0.0:
		_goal = want
	else:
		_hold -= dt

	pull = _ease(pull, PULLS[_goal.x], dt)
	lift = _ease(lift, LIFTS[_goal.y], dt)


func _cost(step: Vector2i) -> float:
	return PULLS[step.x] * PULL_COST + LIFTS[step.y] * LIFT_COST


func _ease(current: float, goal: float, dt: float) -> float:
	var rate := attack if goal > current else release
	return current + (goal - current) * (1.0 - exp(-rate * dt))
