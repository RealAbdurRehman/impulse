class_name GunHolder
extends Node


class Grip:
	var hole := Vector3.ZERO
	var frame := Basis.IDENTITY
	var depth := 0.05
	var width := 0.035
	var side := 1.0
	var extend_index := false


@export var gun_scene: PackedScene
@export var spine: SpineModifier
@export var ragdoll: PhysicalBoneSimulator3D

@export_group("Gun scene")
@export var main_marker: StringName = &"GripMain"
@export var support_marker: StringName = &"GripSupport"
@export var muzzle_marker: StringName = &"Muzzle"
@export var hidden_parts: Array[StringName] = [&"MagFull", &"Bullet", &"BulletCasing"]

@export_group("Main grip")
@export var main_depth := 0.053
@export var main_width := 0.035
@export var trigger_finger := true

@export_range(-90.0, 90.0) var main_tilt_degrees := 22.0

@export_group("Support grip")
@export var support_depth := 0.053
@export var support_width := 0.035

@export_range(-90.0, 90.0) var support_tilt_degrees := 22.0

@export_group("Hands")
@export var palm_width := 0.082
@export var palm_thickness := 0.032
@export var palm_heel := 0.0285

@export var finger_radius := 0.011

var gun: Node3D
var muzzle: Node3D

var main_hand: PhysicalBone3D
var support_hand: PhysicalBone3D

var _main_marker: Node3D
var _support_marker: Node3D


func _ready() -> void:
	if gun_scene == null or spine == null or ragdoll == null:
		return

	main_hand = _find_hand(&"RightHand")
	support_hand = _find_hand(&"LeftHand")
	if main_hand == null or support_hand == null:
		return

	gun = gun_scene.instantiate() as Node3D
	if gun == null:
		return

	_main_marker = gun.get_node_or_null(NodePath(main_marker)) as Node3D
	_support_marker = gun.get_node_or_null(NodePath(support_marker)) as Node3D
	if _main_marker == null or _support_marker == null:
		push_warning(
			"GunHolder: the gun scene needs %s and %s markers" % [main_marker, support_marker]
		)
		return

	muzzle = gun.get_node_or_null(NodePath(muzzle_marker)) as Node3D

	for n in hidden_parts:
		var part := gun.get_node_or_null(NodePath(n))
		if part is Node3D:
			part.visible = false

	_assemble.call_deferred()


func muzzle_transform() -> Transform3D:
	var t := muzzle.global_transform if muzzle != null else gun.global_transform
	t.basis = t.basis.orthonormalized()
	return t


func _assemble() -> void:
	var main := _grip(_main_marker, main_tilt_degrees, main_depth, main_width, 1.0)
	main.extend_index = trigger_finger

	var support := _grip(_support_marker, support_tilt_degrees, support_depth, support_width, -1.0)

	var main_in_gun := _hand_frame(main)
	var support_in_gun := _hand_frame(support)

	var material := _hand_material(main_hand)
	_build_fist(main_hand, main_in_gun, main, material)
	_build_fist(support_hand, support_in_gun, support, material)

	main_hand.add_child(gun)
	gun.transform = (
		main_hand.body_offset.affine_inverse() * main_in_gun.affine_inverse()
		* Transform3D(Basis.from_scale(gun.scale), Vector3.ZERO)
	)

	spine.gun_anchor = (main.hole + support.hole) * 0.5
	spine.gun_muzzle = _gun_space(muzzle).origin if muzzle != null else spine.gun_anchor
	spine.hold_main = main_in_gun
	spine.hold_support = support_in_gun
	spine.gun_equipped = true


func _gun_space(marker: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = marker
	while n != null and n != gun:
		if n is Node3D:
			t = (n as Node3D).transform * t

		n = n.get_parent()

	return Transform3D(t.basis.orthonormalized(), t.origin * gun.scale)


func _grip(marker: Node3D, tilt: float, depth: float, width: float, side: float) -> Grip:
	var t := _gun_space(marker)

	var g := Grip.new()
	g.hole = t.origin
	g.frame = t.basis * Basis(Vector3.BACK, -deg_to_rad(tilt))
	g.depth = depth
	g.width = width
	g.side = side
	return g


func _hand_frame(g: Grip) -> Transform3D:
	var y_axis := g.frame.x
	var z_axis := -g.frame.z * g.side
	var x_axis := y_axis.cross(z_axis)

	var wrist := g.hole - y_axis * (palm_heel + g.depth * 0.5)
	wrist -= z_axis * (palm_thickness * 0.5 + g.width * 0.5)

	return Transform3D(Basis(x_axis, y_axis, z_axis), wrist)


func _build_fist(
	hand: PhysicalBone3D,
	hand_in_gun: Transform3D,
	g: Grip,
	material: Material,
) -> void:
	for n in [&"Hand", &"Thumb"]:
		var old := hand.get_node_or_null(NodePath(n))
		if old is Node3D:
			old.visible = false

	var fist := Node3D.new()
	fist.name = "Fist"
	hand.add_child(fist)
	fist.transform = hand.body_offset.affine_inverse()

	var to_bone := hand_in_gun.affine_inverse()
	var r := finger_radius
	var palm_len := palm_heel + g.depth + r

	var palm := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(palm_width, palm_len, palm_thickness)
	palm.mesh = box
	palm.material_override = material
	palm.position = Vector3(0.0, palm_len * 0.5, 0.0)
	fist.add_child(palm)

	var palm_w := g.width * 0.5 + palm_thickness * 0.5
	var front := g.depth * 0.5 + r
	var far := -(g.width * 0.5 + r)
	var gap := palm_width * 0.25

	for i in 4:
		var y := (1.5 - float(i)) * gap
		if i == 0 and g.extend_index:
			var base := _grip_point(g, front - 0.004, y, palm_w)
			var tip := base + Vector3(0.07, 0.006, 0.0) - g.frame.z * g.side * 0.005
			_rod(fist, to_bone * base, to_bone * tip, r, material)
			continue

		var path: Array[Vector3] = [
			_grip_point(g, front - 0.006, y, palm_w),
			_grip_point(g, front, y, palm_w - 0.026),
			_grip_point(g, front, y, -g.width * 0.5 + 0.001),
			_grip_point(g, front - 0.016, y, far),
			_grip_point(g, front - 0.036, y, far),
		]
		for k in path.size() - 1:
			_rod(fist, to_bone * path[k], to_bone * path[k + 1], r, material)

	var thumb_base := _grip_point(g, -g.depth * 0.5, palm_width * 0.5 - 0.004, palm_w)
	var thumb_mid := thumb_base + Vector3(0.032, 0.002, 0.0) - g.frame.z * g.side * 0.004
	var thumb_tip := thumb_mid + Vector3(0.032, 0.003, 0.0) - g.frame.z * g.side * 0.002
	_rod(fist, to_bone * thumb_base, to_bone * thumb_mid, r * 1.1, material)
	_rod(fist, to_bone * thumb_mid, to_bone * thumb_tip, r * 1.05, material)


func _grip_point(g: Grip, x: float, y: float, w: float) -> Vector3:
	return g.hole + g.frame.x * x + g.frame.y * y + g.frame.z * (g.side * w)


func _rod(parent: Node3D, from: Vector3, to: Vector3, radius: float, material: Material) -> void:
	var delta := to - from
	var length := delta.length()
	if length < 0.0005:
		return

	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = length + radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 4

	var y := delta / length
	var helper := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := y.cross(helper).normalized()

	var rod := MeshInstance3D.new()
	rod.mesh = mesh
	rod.material_override = material
	rod.transform = Transform3D(Basis(x, y, x.cross(y)), (from + to) * 0.5)
	parent.add_child(rod)


func _hand_material(hand: PhysicalBone3D) -> Material:
	var old := hand.get_node_or_null(^"Hand") as MeshInstance3D
	if old != null and old.material_override != null:
		return old.material_override

	var fallback := StandardMaterial3D.new()
	fallback.albedo_color = Color(0.91, 0.455, 0.231)
	fallback.roughness = 0.8
	return fallback


func _find_hand(suffix: StringName) -> PhysicalBone3D:
	for c in ragdoll.get_children():
		if c is PhysicalBone3D and String(c.bone_name).ends_with(String(suffix)):
			return c

	return null
