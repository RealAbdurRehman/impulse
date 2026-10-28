class_name Surfaces
extends RefCounted

const STYLES := {
	&"flesh": preload("res://assets/surfaces/flesh.tres"),
	&"glass": preload("res://assets/surfaces/glass.tres"),
	&"wood": preload("res://assets/surfaces/wood.tres"),
	&"concrete": preload("res://assets/surfaces/concrete.tres"),
	&"metal": preload("res://assets/surfaces/metal.tres"),
	&"plastic": preload("res://assets/surfaces/plastic.tres"),
}


static func of(collider: Object) -> StringName:
	if Hitboxes.bone_of(collider) != null:
		return &"flesh"

	var node := collider as Node
	while node != null:
		if node.has_meta(&"surface"):
			return StringName(node.get_meta(&"surface"))

		node = node.get_parent()

	return &"concrete"


static func style(surface: StringName) -> SurfaceStyle:
	return STYLES[surface]



static func tint_of(collider: Object) -> Color:
	var node := collider as Node
	while node != null:
		if node.is_in_group(&"props"):
			if not node.has_meta(&"tint"):
				node.set_meta(&"tint", _paint(node))

			return node.get_meta(&"tint")

		node = node.get_parent()

	return Color.WHITE


static func _paint(prop: Node) -> Color:
	var best: MeshInstance3D = null
	var volume := 0.0
	for found in prop.find_children("*", "MeshInstance3D", true, false):
		var size := (found as MeshInstance3D).mesh.get_aabb().size
		if size.x * size.y * size.z > volume:
			volume = size.x * size.y * size.z
			best = found

	var material := best.mesh.surface_get_material(0) as BaseMaterial3D
	var color := material.albedo_color
	if material.albedo_texture != null:
		var image := material.albedo_texture.get_image()
		if image.is_compressed():
			image.decompress()

		image.resize(1, 1, Image.INTERPOLATE_LANCZOS)
		color *= image.get_pixel(0, 0)

	return Color(color, 1.0)
