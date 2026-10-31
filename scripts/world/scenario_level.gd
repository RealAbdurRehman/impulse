@tool
class_name ScenarioLevel
extends Node3D

@export_range(0.5, 2.0, 0.05) var toughness := 1.0
@export_range(-0.3, 0.3, 0.05) var skill := 0.0
@export_range(0.0, 1.0, 0.05) var wetness := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		_draw_ground()
	elif get_tree().current_scene == self:
		Scenarios.play.call_deferred(get_tree(), Scenarios.id_of(scene_file_path))
	else:
		Wetness.set_level(wetness)
		Wetness.dress(self)


func _draw_ground() -> void:
	var slab := BoxMesh.new()
	slab.size = Vector3(160.0, 1.0, 6.0)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.22, 0.24, 0.27)
	var ground := MeshInstance3D.new()
	ground.mesh = slab
	ground.material_override = paint
	ground.position = Vector3(30.0, -0.5, 0.0)
	add_child(ground, false, Node.INTERNAL_MODE_FRONT)

	for x in range(-10, 71, 5):
		var tick := Label3D.new()
		tick.text = "START" if x == 0 else str(x)
		tick.pixel_size = 0.006
		tick.position = Vector3(x, -0.5, 3.01)
		add_child(tick, false, Node.INTERNAL_MODE_FRONT)
