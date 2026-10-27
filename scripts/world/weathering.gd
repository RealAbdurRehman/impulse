@tool
class_name Weathering
extends RefCounted

const AGE := Color(0.8, 0.77, 0.74)
const TINTS := {
	&"MI_InteriorFloor": Color(0.48, 0.43, 0.38),
	&"MI_InteriorRoof": Color(0.55, 0.52, 0.5),
	&"MI_InteriorWall": Color(0.62, 0.58, 0.55),
	&"MI_RedBrick": Color(0.74, 0.7, 0.66),
	&"MI_Trim": Color(0.7, 0.68, 0.63),
	&"MI_Trim_Green": Color(0.6, 0.57, 0.5),
	&"MI_Roof_Slate": Color(0.7, 0.7, 0.72),
	&"Rocks": Color(0.6, 0.58, 0.56),
	&"PathRocks": Color(0.62, 0.6, 0.58),
}


static func far(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func fix(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		if mesh == null:
			continue

		for i in mesh.get_surface_count():
			var material := mesh.surface_get_material(i) as BaseMaterial3D
			if material != null and not material.has_meta(&"weathered"):
				material.set_meta(&"weathered", true)
				material.vertex_color_use_as_albedo = false
				material.albedo_color *= TINTS.get(material.resource_name, AGE)
