@tool
class_name ScenarioMarker
extends Marker3D

var _tag: Label3D
var _paint: StandardMaterial3D


func _ready() -> void:
	if not Engine.is_editor_hint():
		return

	_paint = StandardMaterial3D.new()
	_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var shape := MeshInstance3D.new()
	shape.mesh = _mesh()
	shape.material_override = _paint
	shape.position.y = _height() * 0.5
	add_child(shape, false, Node.INTERNAL_MODE_FRONT)

	_tag = Label3D.new()
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.pixel_size = 0.006
	_tag.outline_size = 12
	_tag.position.y = _height() + 0.3
	add_child(_tag, false, Node.INTERNAL_MODE_FRONT)
	_refresh()


func release(_menu: SpawnMenu) -> void:
	pass


func _refresh() -> void:
	if _tag != null:
		_tag.text = _caption()
		_paint.albedo_color = _color()


func _caption() -> String:
	return ""


func _color() -> Color:
	return Color.WHITE


func _mesh() -> Mesh:
	return null


func _height() -> float:
	return 1.0
