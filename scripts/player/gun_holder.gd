class_name GunHolder
extends Node

signal assembled


class Grip:
	var hole := Vector3.ZERO
	var frame := Basis.IDENTITY
	var depth := 0.05
	var width := 0.035
	var block := Transform3D.IDENTITY
	var span := Vector2.ZERO
	var cover := 1.0
	var side := 1.0
	var yaw := 0.0
	var wrist := Transform3D.IDENTITY


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
@export var selector_marker: StringName = &"SelectorPad"

@export_group("Wrist")
@export var wrist_back := 0.0285
@export var wrist_out := 0.016

@export_group("Hands")
@export var hand_width := 0.08
@export var hand_skin := 0.008
@export var support_proud := 0.008

@export_group("Thumb")
@export var thumb_size := Vector3(0.036, 0.018, 0.018)
@export var thumb_at := Vector2(0.0, 0.004)

@export_group("Selector")
@export var selector_gap := 0.004

@export_group("Trigger finger")
@export var finger_size := Vector2(0.017, 0.017)
@export var finger_inset := 0.006
@export var finger_overreach := 0.006
@export var trigger_travel := 0.005
@export var trigger_curl_degrees := 12.0

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
var selector_pad: Node3D
var selector_by_support := false

var main_hand: PhysicalBone3D
var support_hand: PhysicalBone3D

var main_grip: Grip
var support_grip: Grip

var _main_marker: Node3D
var _support_marker: Node3D

var _support_box := Transform3D.IDENTITY
var _support_depth := 0.0
var _thumb: Node3D
var _thumb_at := Vector3.ZERO
var _thumb_to_hand := Transform3D.IDENTITY
var _finger: Node3D
var _finger_rest := Transform3D.IDENTITY


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
	selector_pad = _marker(selector_marker)

	for n in [stats.spare_mag_part, stats.feed_part, stats.casing_part]:
		(gun.get_node(NodePath(n)) as Node3D).visible = false

	_assemble.call_deferred()


func release() -> void:
	gun.queue_free()
	_thumb.queue_free()
	_finger.queue_free()


func muzzle_transform() -> Transform3D:
	var t := muzzle.global_transform
	t.basis = t.basis.orthonormalized()
	return t


func operate_selector(contact: Vector3, amount: float) -> void:
	if selector_by_support:
		_reach_with_support(contact, amount)
	else:
		_flick_thumb(contact, amount)


func _reach_with_support(contact: Vector3, amount: float) -> void:
	var out := signf(contact.z)
	var rest := _support_box.origin
	var target := contact + Vector3(0.0, 0.0, out * (selector_gap + _support_depth))

	spine.support_shift = Vector3(
		(target.x - rest.x) * amount,
		(target.y - rest.y) * amount,
		(target.z - rest.z) * smoothstep(0.0, 0.6, amount),
	)
	spine.support_reach = amount


func _fit_support_box(to_hand: Transform3D) -> void:
	var palm := support_hand.get_node(^"Hand") as MeshInstance3D
	var size := (palm.mesh as BoxMesh).size

	_support_box = to_hand.affine_inverse() * palm.transform
	_support_depth = 0.5 * (
		absf(_support_box.basis.x.z) * size.x + absf(_support_box.basis.y.z) * size.y
		+ absf(_support_box.basis.z.z) * size.z
	)
	selector_by_support = selector_pad != null and _gun_space(selector_pad).origin.z < 0.0


func _flick_thumb(contact: Vector3, amount: float) -> void:
	var half := thumb_size.x * 0.5
	var reach := Vector3(contact.x, contact.y, _thumb_at.z)
	var along := (reach - (_thumb_at - Vector3(half, 0.0, 0.0))).normalized()

	var centre := _thumb_at.lerp(reach - along * half, amount)
	var angle := atan2(along.y, along.x) * amount
	_thumb.transform = _thumb_to_hand * Transform3D(Basis(Vector3.BACK, angle), centre)


func pull_trigger(amount: float) -> void:
	_finger.transform = _finger_rest * Transform3D(
		Basis(Vector3.BACK, -deg_to_rad(trigger_curl_degrees) * amount),
		Vector3(0.0, -trigger_travel * amount, 0.0),
	)


func _marker(marker_name: StringName) -> Node3D:
	return gun.find_child(String(marker_name), true, false) as Node3D


func _assemble() -> void:
	var stats := weapon.stats

	main_grip = _grip(
		stats.main_grip_part,
		_main_marker,
		stats.main_grip_axis,
		Vector3.FORWARD,
		stats.main_grip_yaw_degrees,
		1.0,
	)
	support_grip = _grip(
		stats.support_grip_part,
		_support_marker,
		stats.support_grip_axis,
		stats.support_palm_facing,
		stats.support_grip_yaw_degrees,
		-1.0,
	)

	support_grip.cover = stats.support_grip_cover

	var main_in_gun := _bone_frame(main_grip)
	var support_in_gun := _bone_frame(support_grip)

	var main_to_hand := _build_palm(main_hand, main_in_gun, main_grip)
	var support_to_hand := _build_palm(support_hand, support_in_gun, support_grip)
	_fit_support_box(support_to_hand)
	_build_thumb(main_hand, main_to_hand, main_grip)
	_build_finger(main_hand, main_to_hand, main_grip)
	pull_trigger(0.0)

	main_hand.add_child(gun)
	gun.transform = (
		main_hand.body_offset.affine_inverse() * main_in_gun.affine_inverse()
		* Transform3D(Basis.from_scale(gun.scale), Vector3.ZERO)
	)

	spine.ads_eye_distance = stats.ads_eye_distance
	spine.elbow_flare_degrees = stats.hold_elbow_flare_degrees
	spine.support_flare_degrees = stats.support_elbow_flare_degrees
	spine.low_aim_raise = stats.low_aim_raise
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
	spine.support_turn_degrees = stats.selector_hand_turn_degrees
	spine.support_shift = Vector3.ZERO
	spine.support_reach = 0.0
	var arms := spine.left_arm_bones.duplicate()
	arms.append_array(spine.right_arm_bones)
	spine.clearance = ArmClearance.new(ragdoll, spine.get_skeleton(), arms)
	spine.gun_equipped = true
	assembled.emit()


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
	g.block = Transform3D(fit.block.basis, fit.block.origin * gun.scale)
	g.span = fit.span * gun.scale.x
	g.side = side
	g.yaw = deg_to_rad(yaw)
	g.wrist = _hand_frame(g)
	return g


func _hand_frame(g: Grip) -> Transform3D:
	var y_axis := g.frame.x
	var z_axis := -g.frame.z * g.side
	var x_axis := y_axis.cross(z_axis)

	var wrist := g.hole - y_axis * (wrist_back + g.depth * 0.5)
	wrist -= z_axis * (wrist_out + g.width * 0.5)

	return Transform3D(Basis(x_axis, y_axis, z_axis), wrist)


func _bone_frame(g: Grip) -> Transform3D:
	return Transform3D(g.wrist.basis * Basis(Vector3.BACK, g.yaw), g.wrist.origin)


func _build_palm(hand: PhysicalBone3D, hand_in_gun: Transform3D, g: Grip) -> Transform3D:
	var to_hand := hand.body_offset.affine_inverse() * hand_in_gun.affine_inverse()

	var skin := hand_skin if g.side > 0.0 else hand_skin + support_proud

	var across := g.span.x * g.cover

	var palm := hand.get_node(^"Hand") as MeshInstance3D
	(palm.mesh as BoxMesh).size = Vector3(hand_width, across + skin * 2.0, g.span.y + skin * 2.0)
	palm.transform = to_hand * g.block * Transform3D(
		Basis.IDENTITY,
		Vector3(0.0, (g.span.x - across) * 0.5, 0.0),
	)

	return to_hand


func _build_thumb(hand: PhysicalBone3D, to_hand: Transform3D, g: Grip) -> void:
	var at := g.block.origin + g.block.basis.x * (hand_width * 0.5)
	at += Vector3(thumb_at.x, thumb_at.y, 0.0)
	at.z = _near(g, thumb_size.z)

	_thumb = Node3D.new()
	hand.add_child(_thumb)
	_thumb_at = at
	_thumb_to_hand = to_hand
	_block(_thumb, Transform3D.IDENTITY, thumb_size)
	_flick_thumb(at, 0.0)


func _build_finger(hand: PhysicalBone3D, to_hand: Transform3D, g: Grip) -> void:
	var base := g.block.origin
	base += g.block.basis.y * (g.span.x * 0.5 + hand_skin - finger_inset)
	base += g.block.basis.x * (hand_width * 0.5 - finger_size.x * 0.5 - hand_skin * 0.5)
	base.z = _near(g, finger_size.y)

	var pad := _gun_space(trigger_pad).origin
	pad.z = base.z

	var along := (pad - base).normalized()
	var length := base.distance_to(pad) + finger_overreach

	_finger = Node3D.new()
	hand.add_child(_finger)
	_finger_rest = to_hand * Transform3D(
		Basis(along.cross(Vector3.BACK), along, Vector3.BACK),
		base,
	)

	_block(
		_finger,
		Transform3D(Basis.IDENTITY, Vector3(0.0, length * 0.5, 0.0)),
		Vector3(finger_size.x, length, finger_size.y),
	)


func _near(g: Grip, thickness: float) -> float:
	return g.block.origin.z + g.span.y * 0.5 + hand_skin - thickness * 0.5


func _block(parent: Node3D, at: Transform3D, size: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size

	var block := MeshInstance3D.new()
	block.mesh = box
	block.material_override = (main_hand.get_node(^"Hand") as MeshInstance3D).material_override
	parent.add_child(block)
	block.transform = at


func _find_hand(suffix: StringName) -> PhysicalBone3D:
	for c in ragdoll.get_children():
		if c is PhysicalBone3D and String(c.bone_name).ends_with(String(suffix)):
			return c

	return null
