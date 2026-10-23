class_name Surfaces
extends RefCounted

const STYLES := {
	&"flesh": preload("res://assets/surfaces/flesh.tres"),
	&"glass": preload("res://assets/surfaces/glass.tres"),
	&"drywall": preload("res://assets/surfaces/drywall.tres"),
	&"wood": preload("res://assets/surfaces/wood.tres"),
	&"sand": preload("res://assets/surfaces/sand.tres"),
	&"brick": preload("res://assets/surfaces/brick.tres"),
	&"dirt": preload("res://assets/surfaces/dirt.tres"),
	&"concrete": preload("res://assets/surfaces/concrete.tres"),
	&"metal": preload("res://assets/surfaces/metal.tres"),
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
