@tool
class_name StealthZone
extends Node3D

@export var size := Vector3(4.0, 2.2, 3.0)
@export_range(0.0, 1.0) var visibility := 0.35
@export var color := Color(0.0, 0.0, 0.05, 0.35)

static var _zones: Array[StealthZone] = []


static func at(point: Vector3) -> float:
	var seen := 1.0
	for zone in _zones:
		var offset := (point - zone.global_position).abs()
		if offset.x <= zone.size.x * 0.5 and offset.y <= zone.size.y * 0.5 and offset.z <= zone.size.z * 0.5:
			seen = minf(seen, zone.visibility)

	return seen


func _ready() -> void:
	var box := BoxMesh.new()
	box.size = size

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color

	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.material_override = material
	add_child(mesh)

	if not Engine.is_editor_hint():
		_zones.append(self)


func _exit_tree() -> void:
	_zones.erase(self)
