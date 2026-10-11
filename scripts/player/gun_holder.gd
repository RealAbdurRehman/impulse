class_name GunHolder
extends Node


class Grip:
	var hole := Vector3.ZERO
	var frame := Basis.IDENTITY
	var depth := 0.05
	var width := 0.035
	var outline := PackedVector2Array()
	var side := 1.0
	var yaw := 0.0
	var wrist := Transform3D.IDENTITY
	var extend_index := false


@export var weapon: Weapon
@export var spine: SpineModifier
@export var ragdoll: PhysicalBoneSimulator3D

@export_group("Gun scene")
@export var main_marker: StringName = &"GripMain"
@export var support_marker: StringName = &"GripSupport"
@export var muzzle_marker: StringName = &"Muzzle"
@export var ejector_marker: StringName = &"Ejector"
@export var trigger_marker: StringName = &"TriggerPad"
@export var sight_marker: StringName = &"Sight"
@export var rack_marker: StringName = &"RackGrab"
@export var feed_start_marker: StringName = &"FeedStart"
@export var feed_end_marker: StringName = &"FeedEnd"
@export var barrel_pivot_marker: StringName = &"BarrelPivot"
@export var shoulder_marker: StringName = &"ShoulderPad"

@export_group("Hands")
@export var palm_width := 0.082
@export var palm_thickness := 0.032
@export var palm_heel := 0.0285

@export var finger_radius := 0.0085
@export var finger_lengths: Array[float] = [0.085, 0.092, 0.084, 0.07]
@export var finger_step := 0.01

@export_group("Trigger finger")
@export var finger_segments := Vector2(0.034, 0.026)
@export var finger_bend := Vector3(0.1, 0.0, 1.0)

var gun: Node3D
var muzzle: Node3D
var ejector: Node3D
var trigger_pad: Node3D
var sight: Node3D
var rack_grab: Node3D
var feed_start: Node3D
var feed_end: Node3D
var barrel_pivot: Node3D
var shoulder_pad: Node3D

var main_hand: PhysicalBone3D
var support_hand: PhysicalBone3D

var main_grip: Grip
var support_grip: Grip

var _main_marker: Node3D
var _support_marker: Node3D

var _finger: Array[MeshInstance3D] = []
var _finger_to_bone := Transform3D.IDENTITY
var _finger_base := Vector3.ZERO
var _finger_side := 1.0


func _ready() -> void:
	main_hand = _find_hand(&"RightHand")
	support_hand = _find_hand(&"LeftHand")

	var stats := weapon.stats
	gun = stats.scene.instantiate() as Node3D

	_main_marker = _marker(main_marker)
	_support_marker = _marker(support_marker)
	muzzle = _marker(muzzle_marker)
	ejector = _marker(ejector_marker)
	trigger_pad = _marker(trigger_marker)
	sight = _marker(sight_marker)
	rack_grab = _marker(rack_marker)
	feed_start = _marker(feed_start_marker)
	feed_end = _marker(feed_end_marker)
	barrel_pivot = _marker(barrel_pivot_marker)
	shoulder_pad = _marker(shoulder_marker)

	for n in [stats.spare_mag_part, stats.feed_part, stats.casing_part]:
		(gun.get_node(NodePath(n)) as Node3D).visible = false

	_assemble.call_deferred()


func muzzle_transform() -> Transform3D:
	var t := muzzle.global_transform
	t.basis = t.basis.orthonormalized()
	return t


func _marker(marker_name: StringName) -> Node3D:
	return gun.find_child(String(marker_name), true, false) as Node3D


func _assemble() -> void:
	var stats := weapon.stats

	var main := _grip(
		stats.main_grip_part,
		_main_marker,
		stats.main_grip_axis,
		Vector3.FORWARD,
		stats.main_grip_yaw_degrees,
		1.0,
	)
	main.extend_index = stats.trigger_finger

	var support := _grip(
		stats.support_grip_part,
		_support_marker,
		stats.support_grip_axis,
		stats.support_palm_facing,
		stats.support_grip_yaw_degrees,
		-1.0,
	)

	main_grip = main
	support_grip = support

	var main_in_gun := _bone_frame(main)
	var support_in_gun := _bone_frame(support)

	var material := (main_hand.get_node(^"Hand") as MeshInstance3D).material_override
	_build_fist(main_hand, main_in_gun, main, material)
	_build_fist(support_hand, support_in_gun, support, material)

	if has_trigger_finger():
		pose_trigger_finger(_gun_space(trigger_pad).origin)

	main_hand.add_child(gun)
	gun.transform = (
		main_hand.body_offset.affine_inverse() * main_in_gun.affine_inverse()
		* Transform3D(Basis.from_scale(gun.scale), Vector3.ZERO)
	)

	spine.ads_eye_distance = stats.ads_eye_distance
	spine.elbow_flare_degrees = stats.hold_elbow_flare_degrees
	spine.support_flare_degrees = stats.support_elbow_flare_degrees
	spine.hold_reach = stats.hold_reach
	spine.hold_reach_min = stats.hold_reach_min
	spine.hold_drop = stats.hold_drop
	spine.hold_side = stats.hold_side
	spine.hold_twist_degrees = stats.hold_twist_degrees
	spine.hold_yaw_degrees = stats.hold_yaw_degrees
	spine.ads_yaw_degrees = stats.ads_yaw_degrees

	spine.gun_anchor = _gun_space(shoulder_pad).origin
	spine.gun_muzzle = _gun_space(muzzle).origin
	spine.gun_sight = _gun_space(sight).origin
	spine.hold_main = main_in_gun
	spine.hold_support = support_in_gun
	spine.gun_equipped = true


func has_trigger_finger() -> bool:
	return _finger.size() == 2


func pose_trigger_finger(pad: Vector3) -> void:
	var l1 := finger_segments.x
	var l2 := finger_segments.y

	var to := pad - _finger_base
	var dist := clampf(to.length(), absf(l1 - l2) + 0.002, (l1 + l2) * 0.999)
	var dir := to.normalized() if to.length_squared() > 0.000001 else Vector3.RIGHT

	var along := (l1 * l1 + dist * dist - l2 * l2) / (2.0 * dist)
	var height := sqrt(maxf(l1 * l1 - along * along, 0.0))

	var hint := Vector3(finger_bend.x, finger_bend.y, finger_bend.z * _finger_side)
	var pole := hint - dir * hint.dot(dir)
	if pole.length_squared() < 0.000001:
		pole = dir.cross(Vector3.UP)

	pole = pole.normalized()

	var joint := _finger_base + dir * along + pole * height
	var tip := _finger_base + dir * dist

	_place_rod(_finger[0], _finger_to_bone * _finger_base, _finger_to_bone * joint)
	_place_rod(_finger[1], _finger_to_bone * joint, _finger_to_bone * tip)


func _gun_space(marker: Node3D) -> Transform3D:
	var t := GripFit.local(marker, gun)
	return Transform3D(t.basis.orthonormalized(), t.origin * gun.scale)


func _grip(
	part: StringName,
	marker: Node3D,
	axis: Vector3,
	palm: Vector3,
	yaw: float,
	side: float,
) -> Grip:
	var fit := GripFit.new(gun, part).fit(GripFit.local(marker, gun).origin, axis, palm, side)

	var g := Grip.new()
	g.hole = fit.hole * gun.scale
	g.frame = Basis(fit.fingers, side * fit.fingers.cross(fit.palm), -side * fit.palm)
	g.depth = fit.depth * gun.scale.x
	g.width = fit.width * gun.scale.x
	for p in fit.outline:
		g.outline.append(p * gun.scale.x)

	g.side = side
	g.yaw = deg_to_rad(yaw)
	g.wrist = _hand_frame(g)
	return g


func _hand_frame(g: Grip) -> Transform3D:
	var y_axis := g.frame.x
	var z_axis := -g.frame.z * g.side
	var x_axis := y_axis.cross(z_axis)

	var wrist := g.hole - y_axis * (palm_heel + g.depth * 0.5)
	wrist -= z_axis * (palm_thickness * 0.5 + g.width * 0.5)

	return Transform3D(Basis(x_axis, y_axis, z_axis), wrist)


func _bone_frame(g: Grip) -> Transform3D:
	return Transform3D(g.wrist.basis * Basis(Vector3.BACK, g.yaw), g.wrist.origin)


func _build_fist(
	hand: PhysicalBone3D,
	hand_in_gun: Transform3D,
	g: Grip,
	material: Material,
) -> void:
	(hand.get_node(^"Hand") as Node3D).visible = false

	var fist := Node3D.new()
	fist.name = "Fist"
	hand.add_child(fist)
	fist.transform = hand.body_offset.affine_inverse()

	var to_bone := hand_in_gun.affine_inverse()
	var r := finger_radius
	var knuckle := _knuckle(g)
	var palm_len := palm_heel + g.depth * 0.5 + knuckle.x

	var palm := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(palm_width, palm_len, palm_thickness)
	palm.mesh = box
	palm.material_override = material
	palm.transform = to_bone * g.wrist * Transform3D(
		Basis.IDENTITY,
		Vector3(0.0, palm_len * 0.5, 0.0),
	)
	fist.add_child(palm)

	var palm_w := -knuckle.y
	var front := g.depth * 0.5 + r
	var gap := palm_width * 0.25

	_rod(
		fist,
		to_bone * _grip_point(g, knuckle.x, 1.5 * gap + 0.004, palm_w),
		to_bone * _grip_point(g, knuckle.x, -1.5 * gap - 0.004, palm_w),
		palm_thickness * 0.5 - 0.002,
		material,
	)

	for i in 4:
		var y := (1.5 - float(i)) * gap
		if i == 0 and g.extend_index:
			_finger_base = _grip_point(g, front - 0.004, y, palm_w)
			_finger_to_bone = to_bone
			_finger_side = g.side
			_finger.clear()
			_finger.append(_rod(fist, Vector3.ZERO, Vector3.UP * finger_segments.x, r, material))
			_finger.append(
				_rod(fist, Vector3.ZERO, Vector3.UP * finger_segments.y, r * 0.9, material)
			)

			continue

		var path := _finger_path(g, finger_lengths[i])
		for k in path.size() - 1:
			var tip := 1.0 if k < path.size() - 2 else 0.85
			_rod(
				fist,
				to_bone * _grip_point(g, path[k].x, y, -path[k].y),
				to_bone * _grip_point(g, path[k + 1].x, y, -path[k + 1].y),
				r * tip,
				material,
			)

	var thumb_base := _grip_point(g, -g.depth * 0.5, palm_width * 0.5 - 0.004, palm_w)
	var thumb_mid := thumb_base + Vector3(0.032, 0.002, 0.0) - g.frame.z * g.side * 0.004
	var thumb_tip := thumb_mid + Vector3(0.032, 0.003, 0.0) - g.frame.z * g.side * 0.002
	_rod(fist, to_bone * thumb_base, to_bone * thumb_mid, r * 1.1, material)
	_rod(fist, to_bone * thumb_mid, to_bone * thumb_tip, r * 1.05, material)


func _knuckle(g: Grip) -> Vector2:
	return Vector2(g.depth * 0.5 + finger_radius - 0.006, -(g.width * 0.5 + palm_thickness * 0.5))


func _finger_path(g: Grip, length: float) -> Array[Vector2]:
	var ring := g.outline
	var count := ring.size()

	var offset := PackedVector2Array()
	for j in count:
		var tangent := (ring[(j + 1) % count] - ring[(j + count - 1) % count]).normalized()
		offset.append(ring[j] + Vector2(tangent.y, -tangent.x) * finger_radius)

	var knuckle := _knuckle(g)
	var start := 0
	for j in count:
		if offset[j].distance_to(knuckle) < offset[start].distance_to(knuckle):
			start = j

	var path: Array[Vector2] = [knuckle]
	var left := length
	var from := knuckle
	for j in range(start, start + count):
		var to := offset[j % count]
		var step := from.distance_to(to)
		if step >= left:
			path.append(from.lerp(to, left / step))
			return path

		if to.distance_to(path[-1]) >= finger_step:
			path.append(to)

		left -= step
		from = to

	return path


func _grip_point(g: Grip, x: float, y: float, w: float) -> Vector3:
	return g.hole + g.frame.x * x + g.frame.y * y + g.frame.z * (g.side * w)


func _rod(
	parent: Node3D,
	from: Vector3,
	to: Vector3,
	radius: float,
	material: Material,
) -> MeshInstance3D:
	var delta := to - from
	var length := delta.length()
	if length < 0.0005:
		return null

	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = length + radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 4

	var rod := MeshInstance3D.new()
	rod.mesh = mesh
	rod.material_override = material
	parent.add_child(rod)
	_place_rod(rod, from, to)

	return rod


func _place_rod(rod: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var delta := to - from
	var length := delta.length()
	if length < 0.0005:
		return

	var y := delta / length
	var helper := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := y.cross(helper).normalized()

	rod.transform = Transform3D(Basis(x, y, x.cross(y)), (from + to) * 0.5)


func _find_hand(suffix: StringName) -> PhysicalBone3D:
	for c in ragdoll.get_children():
		if c is PhysicalBone3D and String(c.bone_name).ends_with(String(suffix)):
			return c

	return null
