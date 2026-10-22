class_name Surfaces
extends RefCounted

const RESISTANCE := {
	&"flesh": 1.0,
	&"glass": 0.5,
	&"drywall": 0.4,
	&"wood": 1.5,
	&"brick": 5.0,
	&"concrete": 8.0,
	&"metal": 12.0,
}


static func of(collider: Object) -> StringName:
	if Hitboxes.bone_of(collider) != null:
		return &"flesh"

	if collider.has_meta(&"surface"):
		return StringName(collider.get_meta(&"surface"))

	return &"concrete"


static func resistance(collider: Object) -> float:
	return RESISTANCE[of(collider)]
