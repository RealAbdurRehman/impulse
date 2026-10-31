@tool
class_name BodyLook
extends Node

@export var style: LookStyle:
	set(value):
		if Engine.is_editor_hint():
			if style != null and style.changed.is_connected(_rebuild):
				style.changed.disconnect(_rebuild)

			if value != null:
				value.changed.connect(_rebuild)

		style = value
		if Engine.is_editor_hint() and is_node_ready():
			_rebuild()

@export var ragdoll: PhysicalBoneSimulator3D

const KEPT := [&"Hand", &"Neck"]

static var _shared := { }

var _bones := { }
var _bases := { }
var _kits := { }
var _skeleton: Skeleton3D

var _uniform: StandardMaterial3D
var _vest: StandardMaterial3D
var _pouch: StandardMaterial3D
var _helmet: StandardMaterial3D
var _mask: StandardMaterial3D
var _glove: StandardMaterial3D
var _boot: StandardMaterial3D
var _pad: StandardMaterial3D
var _tag: StandardMaterial3D
var _flesh: StandardMaterial3D


func _ready() -> void:
	if Engine.is_editor_hint() and (ragdoll == null or style == null):
		return

	_build()


func _rebuild() -> void:
	if not is_node_ready():
		return

	for bone: PhysicalBone3D in _bones.values():
		var old := bone.get_node_or_null(^"Look")
		if old != null:
			bone.remove_child(old)
			old.free()

	_bones.clear()
	_bases.clear()
	_kits.clear()
	if ragdoll != null and style != null:
		_build()


func _build() -> void:
	_skeleton = ragdoll.get_parent() as Skeleton3D
	_make_materials()

	var player := get_parent() as Node3D
	var to_player := player.global_transform.affine_inverse() * _skeleton.global_transform

	for body in ragdoll.get_children():
		var bone := body as PhysicalBone3D
		if bone == null:
			continue

		var part := String(bone.bone_name).get_slice("_", 1)
		var rest := to_player * _skeleton.get_bone_global_rest(_skeleton.find_bone(bone.bone_name)) * bone.body_offset
		_bones[part] = bone
		_bases[part] = _design_basis(part, rest.basis.orthonormalized().inverse())
		_kits[part] = MeshKit.new()

		if not Engine.is_editor_hint():
			for mesh in bone.find_children("*", "MeshInstance3D", true, false):
				if not KEPT.has(mesh.name):
					(mesh as MeshInstance3D).visible = false

	if not Engine.is_editor_hint():
		_paint_kept()

	var meshes := _meshes()
	for part in meshes:
		var look := MeshInstance3D.new()
		look.name = &"Look"
		look.mesh = meshes[part]
		look.transform = Transform3D(_bases[part], Vector3.ZERO)
		(_bones[part] as PhysicalBone3D).add_child(look)


func _meshes() -> Dictionary:
	if not Engine.is_editor_hint() and _shared.has(style):
		return _shared[style]

	_build_pelvis()
	_build_torso()
	_build_head()
	for side in ["Left", "Right"]:
		_build_arm(side)
		_build_leg(side)
		_build_foot(side)

	var meshes := { }
	for part in _kits:
		var kit: MeshKit = _kits[part]
		if not kit.is_empty():
			meshes[part] = kit.build()

	if not Engine.is_editor_hint():
		_shared[style] = meshes

	return meshes


func _paint_kept() -> void:
	_proxy("Spine1", "Neck").material_override = _mask
	for side in ["Left", "Right"]:
		_proxy(side + "Hand", "Hand").material_override = _glove


func _proxy(part: String, node: String) -> MeshInstance3D:
	return (_bones[part] as PhysicalBone3D).get_node(NodePath(node)) as MeshInstance3D


func _make_materials() -> void:
	_uniform = _material(style.uniform, 0.92)
	_vest = _material(style.vest, 0.85)
	_pouch = _material(style.pouch, 0.85)
	_helmet = _material(style.helmet, 0.6)
	_mask = _material(style.mask, 0.9)
	_glove = _material(style.glove, 0.8)
	_boot = _material(style.boot, 0.75)
	_pad = _material(style.pad, 0.8)
	_tag = _material(style.tag, 0.9)
	_flesh = _material(style.skin, 0.7)

	for material in [_uniform, _vest, _mask, _flesh]:
		material.resource_name = &"body"


func _material(colour: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	material.metallic = metallic
	material.rim_enabled = true
	material.rim = 0.1
	material.rim_tint = 0.5
	return material


func _design_basis(part: String, rest_inverse: Basis) -> Basis:
	if part.ends_with("Foot"):
		return Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)

	if part.ends_with("Arm") or part.ends_with("Hand") or part.ends_with("Leg"):
		var up := Vector3.DOWN
		var forward := rest_inverse.z - up * rest_inverse.z.dot(up)
		forward = forward.normalized()
		return Basis(up.cross(forward), up, forward)

	return rest_inverse


func _at(position := Vector3.ZERO, degrees := Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(degrees * (PI / 180.0)), position)


func _length(part: String) -> float:
	return (_bones[part] as PhysicalBone3D).body_offset.origin.length() * 2.0


func _limb(part: String, stops: Array, cap_top := 0.03, cap_bottom := 0.025, sides := 14) -> Dictionary:
	var length := _length(part)
	var rings := []
	for stop in stops:
		var s: Vector4 = stop
		rings.append(
			Vector4(
				(0.5 - s.x) * length,
				s.y * style.bulk,
				s.z * style.bulk,
				s.w,
			),
		)

	return MeshKit.limb(rings, sides, cap_top, cap_bottom)


func _build_pelvis() -> void:
	var k: MeshKit = _kits["Hips"]
	k.add(_uniform, MeshKit.box(Vector3(0.315, 0.2, 0.21), 0.065, 3, Vector2.ONE, Vector2(0.9, 0.92)), _at(Vector3(0.0, -0.04, 0.0)))
	k.add(_pad, MeshKit.box(Vector3(0.33, 0.058, 0.226), 0.022), _at(Vector3(0.0, 0.035, 0.0)))
	k.add(_tag, MeshKit.box(Vector3(0.042, 0.04, 0.014), 0.007), _at(Vector3(0.0, 0.035, 0.116)))

	if style.pockets_on:
		for x in [0.1, -0.1]:
			var turn := Vector3(0.0, signf(x) * 14.0, 0.0)
			k.add(_pouch, MeshKit.box(Vector3(0.06, 0.088, 0.05), 0.015), _at(Vector3(x, -0.004, 0.11), turn))
			k.add(_pad, MeshKit.box(Vector3(0.062, 0.03, 0.054), 0.012), _at(Vector3(x, 0.034, 0.112), turn))

		k.add(_pouch, MeshKit.box(Vector3(0.1, 0.06, 0.04), 0.015), _at(Vector3(0.0, -0.005, -0.12)))


func _build_torso() -> void:
	var k: MeshKit = _kits["Spine1"]
	k.add(_uniform, MeshKit.box(Vector3(0.34, 0.37, 0.2), 0.075, 3, Vector2(1.1, 1.0), Vector2(0.9, 0.95)), _at(Vector3(0.0, 0.01, 0.0)))

	if style.vest_on:
		for z in [0.115, -0.115]:
			k.add(_vest, MeshKit.box(Vector3(0.29, 0.31, 0.06), 0.024, 3, Vector2(0.88, 1.0)), _at(Vector3(0.0, 0.03, z)))

		k.add(_vest, MeshKit.box(Vector3(0.342, 0.12, 0.245), 0.05), _at(Vector3(0.0, -0.095, 0.0)))
		for x in [0.105, -0.105]:
			k.add(_vest, MeshKit.box(Vector3(0.07, 0.035, 0.27), 0.016), _at(Vector3(x, 0.188, 0.0)))

		for x in [-0.078, 0.0, 0.078]:
			k.add(_pouch, MeshKit.box(Vector3(0.066, 0.092, 0.036), 0.014), _at(Vector3(x, -0.025, 0.158)))
			k.add(_pad, MeshKit.box(Vector3(0.068, 0.03, 0.04), 0.012), _at(Vector3(x, 0.014, 0.16)))

		k.add(_pouch, MeshKit.box(Vector3(0.17, 0.056, 0.032), 0.014), _at(Vector3(0.0, 0.1, 0.152)))
		k.add(_tag, MeshKit.box(Vector3(0.058, 0.032, 0.008), 0.004), _at(Vector3(0.06, 0.13, 0.171)))
		k.add(_pad, MeshKit.box(Vector3(0.036, 0.075, 0.032), 0.013), _at(Vector3(-0.112, 0.125, 0.15)))

	if style.backpack_on:
		k.add(_pad, MeshKit.box(Vector3(0.25, 0.28, 0.115), 0.05, 3, Vector2(0.92, 1.0), Vector2.ONE), _at(Vector3(0.0, 0.03, -0.205)))
		k.add(_pouch, MeshKit.box(Vector3(0.18, 0.08, 0.04), 0.018), _at(Vector3(0.0, 0.07, -0.268)))


func _build_head() -> void:
	var g := 1.2
	var proxy := _proxy("Head", "Head")
	var centre: Vector3 = (_bases["Head"] as Basis).inverse() * proxy.position + Vector3(0.0, -0.004, 0.0)
	var skull := Vector3(0.081, 0.106, 0.1) * g
	var k: MeshKit = _kits["Head"]

	k.add(_flesh, MeshKit.ellipsoid(skull), _at(centre))
	k.add(_mask, _cap(skull + Vector3.ONE * 0.005, 0.0128 * g, false), _at(centre, Vector3(18.0, 0.0, 0.0)))

	if style.helmet_on:
		k.add(_helmet, _cap(skull + Vector3(0.012, 0.014, 0.016) * g, -0.0052 * g, true), _at(centre, Vector3(-18.0, 0.0, 0.0)))
		k.add(_pad, MeshKit.box(Vector3(0.062, 0.04, 0.036) * g, 0.015), _at(centre + Vector3(0.0, 0.054, 0.108) * g, Vector3(-22.0, 0.0, 0.0)))
		k.add(_pad, MeshKit.box(Vector3(0.09, 0.05, 0.034) * g, 0.016), _at(centre + Vector3(0.0, 0.018, -0.118) * g, Vector3(14.0, 0.0, 0.0)))
		for x in [0.094, -0.094]:
			k.add(_pouch, MeshKit.box(Vector3(0.012, 0.034, 0.07) * g, 0.005), _at(centre + Vector3(x, 0.038, 0.008) * g))

		for x in [0.088, -0.088]:
			k.add(_helmet, MeshKit.ellipsoid(Vector3(0.016, 0.03, 0.034) * g), _at(centre + Vector3(x, -0.028, 0.002) * g))


func _cap(radii: Vector3, cut: float, top: bool) -> Dictionary:
	var limit := acos(clampf(cut / radii.y, -1.0, 1.0))
	var rings := []
	var steps := 10
	for i in steps + 1:
		var angle := limit * float(i) / steps if top else lerpf(limit, PI, float(i) / steps)
		rings.append(MeshKit.ring(radii.y * cos(angle), radii.x * sin(angle), radii.z * sin(angle)))

	return MeshKit.limb(rings, 24, 0.0 if top else 0.007, 0.007 if top else 0.0)


func _build_arm(side: String) -> void:
	var s := 1.0 if side == "Left" else -1.0
	var upper_name := side + "Arm"
	var fore_name := side + "ForeArm"

	var upper := _length(upper_name)
	var upper_kit: MeshKit = _kits[upper_name]
	upper_kit.add(
		_uniform,
		_limb(upper_name, [
			Vector4(0.0, 0.058, 0.062, 0.0),
			Vector4(0.2, 0.059, 0.062, 0.0),
			Vector4(0.55, 0.05, 0.054, 0.0),
			Vector4(0.85, 0.045, 0.048, 0.0),
			Vector4(1.0, 0.044, 0.046, 0.0),
		]),
	)
	upper_kit.add(_uniform, MeshKit.ellipsoid(Vector3.ONE * 0.046 * style.bulk), _at(Vector3(0.0, -upper * 0.5, 0.0)))
	if style.pads_on:
		upper_kit.add(_pouch, MeshKit.ellipsoid(Vector3(0.066, 0.042, 0.066)), _at(Vector3(s * 0.012, upper * 0.5 + 0.012, 0.0), Vector3(0.0, 0.0, -s * 18.0)))

	var fore := _length(fore_name)
	var fore_kit: MeshKit = _kits[fore_name]
	fore_kit.add(
		_uniform,
		_limb(fore_name, [
			Vector4(0.0, 0.045, 0.048, 0.0),
			Vector4(0.15, 0.047, 0.05, 0.0),
			Vector4(0.5, 0.04, 0.042, 0.0),
			Vector4(0.85, 0.034, 0.036, 0.0),
			Vector4(1.0, 0.033, 0.035, 0.0),
		]),
	)
	if style.pads_on:
		fore_kit.add(_pad, MeshKit.ellipsoid(Vector3(0.048, 0.054, 0.036)), _at(Vector3(0.0, fore * 0.5 - 0.012, -0.038)))


func _build_leg(side: String) -> void:
	var s := 1.0 if side == "Left" else -1.0
	var thigh_name := side + "UpLeg"
	var shin_name := side + "Leg"

	var thigh := _length(thigh_name)
	var thigh_kit: MeshKit = _kits[thigh_name]
	thigh_kit.add(
		_uniform,
		_limb(thigh_name, [
			Vector4(0.0, 0.088, 0.092, 0.0),
			Vector4(0.15, 0.093, 0.096, 0.0),
			Vector4(0.45, 0.083, 0.087, 0.0),
			Vector4(0.8, 0.068, 0.071, 0.0),
			Vector4(1.0, 0.063, 0.065, 0.0),
		], 0.035, 0.03, 16),
	)
	if style.pockets_on:
		thigh_kit.add(_pouch, MeshKit.box(Vector3(0.04, 0.14, 0.105), 0.016), _at(Vector3(s * 0.096, thigh * 0.5 - 0.17, 0.0)))
		thigh_kit.add(_pad, MeshKit.box(Vector3(0.044, 0.03, 0.11), 0.014), _at(Vector3(s * 0.097, thigh * 0.5 - 0.125, 0.0)))
		if s < 0.0:
			thigh_kit.add(_pad, MeshKit.box(Vector3(0.05, 0.18, 0.08), 0.02), _at(Vector3(s * 0.112, thigh * 0.5 - 0.2, 0.025)))
			thigh_kit.add(_pad, MeshKit.limb([MeshKit.ring(0.014, 0.0875, 0.092), MeshKit.ring(-0.014, 0.0875, 0.092)], 16, 0.006, 0.006), _at(Vector3(0.0, -thigh * 0.5 + 0.12, 0.0)))

	var shin := _length(shin_name)
	var ankle := -shin * 0.5
	var shin_kit: MeshKit = _kits[shin_name]
	shin_kit.add(
		_uniform,
		_limb(shin_name, [
			Vector4(0.0, 0.063, 0.067, 0.0),
			Vector4(0.12, 0.067, 0.071, 0.0),
			Vector4(0.34, 0.068, 0.072, -0.012),
			Vector4(0.7, 0.052, 0.055, -0.004),
			Vector4(1.0, 0.047, 0.05, 0.0),
		], 0.032, 0.02, 16),
	)
	if style.pads_on:
		shin_kit.add(_pad, MeshKit.box(Vector3(0.1, 0.105, 0.05), 0.022), _at(Vector3(0.0, shin * 0.5 - 0.035, 0.066), Vector3(-8.0, 0.0, 0.0)))

	shin_kit.add(
		_boot,
		MeshKit.limb(
			[
				MeshKit.ring(ankle + 0.17, 0.059, 0.063, -0.004),
				MeshKit.ring(ankle + 0.1, 0.057, 0.061, -0.002),
				MeshKit.ring(ankle + 0.03, 0.056, 0.06, 0.003),
				MeshKit.ring(ankle, 0.052, 0.056, 0.005),
			],
			18,
			0.012,
			0.03,
		),
	)
	shin_kit.add(
		_pad,
		MeshKit.limb([MeshKit.ring(0.012, 0.0615, 0.0655, -0.003), MeshKit.ring(-0.012, 0.0615, 0.0655, -0.003)], 18, 0.006, 0.006),
		_at(Vector3(0.0, ankle + 0.155, 0.0)),
	)


func _build_foot(side: String) -> void:
	var k: MeshKit = _kits[side + "Foot"]
	k.add(_pad, MeshKit.box(Vector3(0.1, 0.027, 0.252), 0.0125, 3), _at(Vector3(0.003, -0.034, -0.032)))
	k.add(_boot, MeshKit.box(Vector3(0.098, 0.24, 0.07), 0.022, 3, Vector2(0.8, 0.8)), _at(Vector3(0.003, -0.002, -0.04), Vector3(90.0, 0.0, 0.0)))
	k.add(_boot, MeshKit.ellipsoid(Vector3(0.062, 0.06, 0.063)), _at(Vector3(0.003, 0.03, -0.111)))
	k.add(_pouch, MeshKit.box(Vector3(0.034, 0.012, 0.11), 0.005), _at(Vector3(0.003, 0.037, -0.04), Vector3(8.0, 0.0, 0.0)))
