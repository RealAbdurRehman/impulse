class_name Wetness
extends RefCounted

const DARKEN := 0.3
const GLOSS := 0.25

static var amount := 0.0


static func set_level(level: float) -> void:
	amount = level
	RenderingServer.global_shader_parameter_set(&"wetness", level)


static func dress(root: Node) -> void:
	if amount <= 0.0:
		return

	var soaked := { }
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for i in mesh.get_surface_override_material_count():
			var dry := mesh.get_active_material(i) as StandardMaterial3D
			if dry == null:
				continue

			if not soaked.has(dry):
				soaked[dry] = _soak(dry)

			mesh.set_surface_override_material(i, soaked[dry])


static func _soak(dry: StandardMaterial3D) -> StandardMaterial3D:
	var wet := dry.duplicate() as StandardMaterial3D
	wet.albedo_color = dry.albedo_color.darkened(DARKEN * amount)
	wet.roughness = dry.roughness * (1.0 - GLOSS * amount)
	return wet
