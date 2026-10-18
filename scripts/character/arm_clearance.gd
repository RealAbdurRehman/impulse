class_name ArmClearance
extends RefCounted

enum Kind {
	BOX,
	CAPSULE,
	SPHERE,
}


class Solid:
	var bone := 0
	var local := Transform3D.IDENTITY
	var kind := Kind.BOX
	var half := Vector3.ZERO
	var radius := 0.0
	var reach := 0.0
	var frame := Transform3D.IDENTITY
	var inverse := Transform3D.IDENTITY


var hand_radius := 0.07
var margin := 0.002
var arm_tolerance := 0.03
var rounds := 5
var max_push := 0.08
var max_total := 0.15
var push_speed := 60.0
var push_rate := 0.6

var _skeleton: Skeleton3D
var _solids: Array[Solid] = []
var _poses := { }
var _upper_radius := 0.06
var _fore_radius := 0.042

var _push := Vector3.ZERO

var _points: Array[Vector3] = []
var _radii: Array[float] = []
var _levers: Array[float] = []


func _init(ragdoll: PhysicalBoneSimulator3D, skeleton: Skeleton3D, arms: Array[StringName]) -> void:
	_skeleton = skeleton

	for body in ragdoll.get_children():
		var bone := body as PhysicalBone3D
		if bone == null:
			continue

		var index := skeleton.find_bone(bone.bone_name)
		for mesh in _meshes(bone):
			if bone.bone_name in arms:
				_read_radius(bone, mesh)
			else:
				_add(index, bone.body_offset * _relative(mesh, bone), mesh.mesh)

	skeleton.skeleton_updated.connect(_snapshot)
	_snapshot()


func resolve(
	shoulder: Vector3,
	wrist: Vector3,
	pole: Vector3,
	upper: float,
	fore: float,
	weight: float,
	dt: float,
) -> Vector3:
	if weight <= 0.0:
		_push = Vector3.ZERO
		return wrist

	for solid in _solids:
		solid.frame = (_poses[solid.bone] as Transform3D) * solid.local
		solid.inverse = solid.frame.affine_inverse()

	var reachable := _reachable(shoulder, wrist, upper, fore)
	var hand := _clear_hand(shoulder, reachable, upper, fore)
	for i in rounds:
		var push := _arm_push(shoulder, hand, pole, upper, fore)
		if push.length_squared() < 0.000001:
			break

		hand = reachable + (hand + push - reachable).limit_length(max_total)
		hand = _clear_hand(shoulder, hand, upper, fore)

	if weight < 0.05:
		_push = Vector3.ZERO

	var step := (hand - reachable - _push) * (1.0 - exp(-push_speed * dt))
	_push += step.limit_length(push_rate * dt)
	return wrist.lerp(_reachable(shoulder, reachable + _push, upper, fore), weight)


func _clear_hand(shoulder: Vector3, wrist: Vector3, upper: float, fore: float) -> Vector3:
	var hand := wrist
	for i in 6:
		var probe := _probe(hand)
		var over := hand_radius + margin - probe.w
		if over <= 0.0:
			break

		hand = _reachable(shoulder, hand + Vector3(probe.x, probe.y, probe.z) * over, upper, fore)

	return hand


func _arm_push(
	shoulder: Vector3,
	wrist: Vector3,
	pole: Vector3,
	upper: float,
	fore: float,
) -> Vector3:
	_arm_points(shoulder, wrist, _elbow(shoulder, wrist, pole, upper, fore))

	var sum := Vector3.ZERO
	var weight := 0.0
	for k in _points.size():
		var probe := _probe(_points[k])
		var over := _radii[k] - arm_tolerance - probe.w
		if over > 0.0:
			sum += Vector3(probe.x, probe.y, probe.z) * over * _levers[k]
			weight += _levers[k] * _levers[k]

	if weight <= 0.0:
		return Vector3.ZERO

	var dir := (wrist - shoulder).normalized()
	var push := sum / weight
	return (push - dir * push.dot(dir)).limit_length(max_push)


func _arm_points(shoulder: Vector3, wrist: Vector3, elbow: Vector3) -> void:
	_points.clear()
	_radii.clear()
	_levers.clear()

	var upper := (elbow - shoulder).length()
	var fore := (wrist - elbow).length()
	var total := upper + fore

	for t in [0.5, 0.75, 1.0]:
		_points.append(shoulder.lerp(elbow, t))
		_radii.append(_upper_radius)
		_levers.append(t * upper / total)

	for t in [0.25, 0.5, 0.75]:
		_points.append(elbow.lerp(wrist, t))
		_radii.append(_fore_radius)
		_levers.append((upper + t * fore) / total)


func _elbow(shoulder: Vector3, wrist: Vector3, pole: Vector3, upper: float, fore: float) -> Vector3:
	var to := wrist - shoulder
	var dist := to.length()
	var dir := to / dist

	var along := (upper * upper + dist * dist - fore * fore) / (2.0 * dist)
	var height := sqrt(maxf(upper * upper - along * along, 0.0))
	var side := (pole - dir * pole.dot(dir)).normalized()

	return shoulder + dir * along + side * height


func _reachable(shoulder: Vector3, wrist: Vector3, upper: float, fore: float) -> Vector3:
	var to := wrist - shoulder
	var dist := clampf(to.length(), absf(upper - fore) + 0.02, (upper + fore) * 0.9995)
	return shoulder + to.normalized() * dist


func _probe(point: Vector3) -> Vector4:
	var best := Vector4(0.0, 0.0, 0.0, INF)

	for solid in _solids:
		if (point - solid.frame.origin).length_squared() > solid.reach:
			continue

		var q := solid.inverse * point
		var d := 0.0
		var n := Vector3.RIGHT

		match solid.kind:
			Kind.BOX:
				var e := q.abs() - solid.half
				var outside := e.max(Vector3.ZERO)
				if outside.length_squared() > 0.0:
					d = outside.length()
					n = Vector3(signf(q.x), signf(q.y), signf(q.z)) * outside / d
				elif e.x >= e.y and e.x >= e.z:
					d = e.x
					n = Vector3(signf(q.x), 0.0, 0.0)
				elif e.y >= e.z:
					d = e.y
					n = Vector3(0.0, signf(q.y), 0.0)
				else:
					d = e.z
					n = Vector3(0.0, 0.0, signf(q.z))

			Kind.CAPSULE:
				var off := q - Vector3(0.0, clampf(q.y, -solid.half.y, solid.half.y), 0.0)
				d = off.length() - solid.radius
				if off.length_squared() > 0.0:
					n = off.normalized()

			Kind.SPHERE:
				d = q.length() - solid.radius
				if q.length_squared() > 0.0:
					n = q.normalized()

		if d < best.w:
			var world := solid.frame.basis * n
			best = Vector4(world.x, world.y, world.z, d)

	return best


func _snapshot() -> void:
	for solid in _solids:
		_poses[solid.bone] = _skeleton.get_bone_global_pose(solid.bone)


func _add(bone: int, local: Transform3D, mesh: Mesh) -> void:
	var solid := Solid.new()
	solid.bone = bone
	solid.local = Transform3D(local.basis.orthonormalized(), local.origin)

	var bound := 0.0
	if mesh is BoxMesh:
		solid.kind = Kind.BOX
		solid.half = (mesh as BoxMesh).size * 0.5
		bound = solid.half.length()
	elif mesh is CapsuleMesh:
		var capsule := mesh as CapsuleMesh
		solid.kind = Kind.CAPSULE
		solid.radius = capsule.radius
		solid.half.y = maxf(capsule.height * 0.5 - capsule.radius, 0.0)
		bound = capsule.height * 0.5
	elif mesh is CylinderMesh:
		var cylinder := mesh as CylinderMesh
		solid.kind = Kind.CAPSULE
		solid.radius = cylinder.top_radius
		solid.half.y = maxf(cylinder.height * 0.5 - cylinder.top_radius, 0.0)
		bound = cylinder.height * 0.5
	elif mesh is SphereMesh:
		solid.kind = Kind.SPHERE
		solid.radius = (mesh as SphereMesh).radius
		bound = solid.radius
	else:
		return

	solid.reach = pow(bound + 0.1, 2.0)
	_solids.append(solid)


func _read_radius(bone: PhysicalBone3D, mesh: MeshInstance3D) -> void:
	var capsule := mesh.mesh as CapsuleMesh
	if capsule == null:
		return

	if String(bone.bone_name).ends_with("ForeArm"):
		_fore_radius = capsule.radius
	else:
		_upper_radius = capsule.radius


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child in node.get_children():
		var mesh := child as MeshInstance3D
		if mesh != null:
			out.append(mesh)

		out.append_array(_meshes(child))

	return out


func _relative(node: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != root:
		t = (n as Node3D).transform * t
		n = n.get_parent()

	return t
