class_name EdgeIndicators
extends CanvasLayer

const SHADER := preload("res://scripts/ui/shaders/edge_mark.gdshader")
const WARM_FRAMES := 4


class Tag:
	var rect := ColorRect.new()
	var material := ShaderMaterial.new()
	var position := Vector2.ZERO
	var drawn := Vector2.ZERO
	var direction := Vector2.LEFT
	var shown := 0.0
	var level := 0.0
	var threat := false
	var age := 9.0
	var alarmed := false
	var fade := 1.0
	var mark := 0.0
	var span := 1.0
	var seed := 0.0


@export var design_height := 1080.0
@export var reach := 12.0
@export var calm_reach := 6.0
@export var icon_size := 64.0
@export var margin := 8.0
@export var fade_distance := 40.0
@export var max_per_side := 3
@export var max_calm_per_side := 2
@export_range(0.0, 1.0) var quiet := 0.55
@export_range(0.0, 1.0) var strength := 0.85

var _tags := { }
var _live: Array[Tag] = []
var _scale := 1.0
var _warm := WARM_FRAMES
var _primer: ColorRect


func _ready() -> void:
	layer = 9
	_primer = ColorRect.new()
	_primer.material = _material()
	_primer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_primer.size = Vector2.ONE * 8.0
	_primer.position = Vector2(-16.0, -16.0)
	add_child(_primer)


func _process(delta: float) -> void:
	if _warm > 0:
		_warm -= 1
		if _warm == 0:
			_primer.queue_free()

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var size := get_viewport().get_visible_rect().size
	_scale = size.y / design_height
	var half := icon_size * 0.5 * _scale
	var inset := half + margin * _scale
	var follow := 1.0 - exp(-14.0 * delta)

	var found: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var brain := node as EnemyInput
		if not brain.health.alive:
			continue

		var level := brain.warning()
		var aware := level >= EnemyMark.FROM
		var world := (brain.get_parent() as Node3D).get_global_transform_interpolated().origin + Vector3.UP * 1.6
		if camera.is_position_behind(world):
			continue

		var point := camera.unproject_position(world)
		var outside := maxf(maxf(-point.x, point.x - size.x), maxf(-point.y, point.y - size.y))
		var known := _tags.has(brain.get_instance_id())
		if outside <= 0.0 and not known:
			continue

		var per_metre := Vector2(
			absf(camera.unproject_position(world + Vector3.RIGHT).x - point.x),
			absf(camera.unproject_position(world + Vector3.UP).y - point.y),
		)
		var beyond := maxf(
			maxf(-point.x, point.x - size.x) / maxf(per_metre.x, 1.0),
			maxf(-point.y, point.y - size.y) / maxf(per_metre.y, 1.0),
		)
		if beyond > (reach if aware else calm_reach) * (1.15 if known else 1.0):
			continue

		var rank := 1.0 - beyond * 0.01
		if aware:
			rank = 2.0 + level + (1.0 if brain.alarmed() else 0.0) - beyond * 0.001

		found.append({ "brain": brain, "level": level, "aware": aware, "beyond": beyond, "point": point, "outside": outside, "rank": rank })

	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.rank > b.rank)

	var seen := { }
	var taken := [[0, 0, 0], [0, 0, 0]]
	for entry in found:
		var point: Vector2 = entry.point
		var edge := Vector2(clampf(point.x, inset, size.x - inset), clampf(point.y, inset, size.y - inset))
		var column := 0 if point.x < 0.0 else (1 if point.x > size.x else 2)
		var aware: bool = entry.aware
		if taken[int(aware)][column] >= (max_per_side if aware else max_calm_per_side):
			continue

		taken[int(aware)][column] += 1
		var brain: EnemyInput = entry.brain
		var id := brain.get_instance_id()
		seen[id] = true

		var tag: Tag = _tags.get(id)
		if tag == null:
			tag = _make_tag(float(id % 97))
			tag.position = edge
			_tags[id] = tag

		if point.distance_to(edge) > 1.0:
			tag.direction = (point - edge).normalized()

		tag.position = tag.position.lerp(edge, follow)
		tag.shown = lerpf(tag.shown, clampf(float(entry.outside) / (fade_distance * _scale), 0.0, 1.0), follow)
		tag.level = lerpf(tag.level, entry.level, 1.0 - exp(-8.0 * delta))
		tag.fade = 1.0 - 0.5 * smoothstep(0.4, 1.0, float(entry.beyond) / (reach if aware else calm_reach))
		tag.mark = lerpf(tag.mark, 1.0 if aware else 0.0, 1.0 - exp(-8.0 * delta))
		tag.span = lerpf(0.55, 1.0, tag.mark)
		var alarm := brain.alarmed()
		if alarm and not tag.alarmed:
			tag.age = 0.0

		tag.alarmed = alarm
		tag.threat = alarm or float(entry.level) >= 0.995
		tag.age += delta

	for id: int in _tags.keys():
		if not seen.has(id):
			var tag: Tag = _tags[id]
			tag.shown = move_toward(tag.shown, 0.0, delta * 4.0)
			if tag.shown <= 0.0:
				tag.rect.queue_free()
				_tags.erase(id)

	_live.clear()
	for tag: Tag in _tags.values():
		tag.drawn = tag.position
		tag.rect.visible = tag.shown > 0.01
		if tag.rect.visible:
			_live.append(tag)

	_space_out(size, inset, half)
	for tag in _live:
		_place(tag, half)


func _make_tag(seed: float) -> Tag:
	var tag := Tag.new()
	tag.seed = seed
	tag.material = _material()
	tag.rect.material = tag.material
	tag.rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tag.rect)
	return tag


func _material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"fade", 0.0)
	return material


func _place(tag: Tag, half: float) -> void:
	var punch := 1.0 + 0.3 * exp(-14.0 * tag.age) if tag.alarmed else 1.0
	tag.rect.size = Vector2.ONE * half * 2.0
	tag.rect.pivot_offset = Vector2.ONE * half
	tag.rect.scale = Vector2.ONE * punch
	tag.rect.position = tag.drawn - Vector2.ONE * half

	tag.material.set_shader_parameter(&"fade", tag.shown * tag.fade * strength * lerpf(quiet, 1.0, tag.mark))
	tag.material.set_shader_parameter(&"marked", tag.mark)
	tag.material.set_shader_parameter(&"gauge", tag.level)
	tag.material.set_shader_parameter(&"bang", 1.0 if tag.threat else 0.0)
	tag.material.set_shader_parameter(&"age", tag.age)
	tag.material.set_shader_parameter(&"seed", tag.seed)
	tag.material.set_shader_parameter(&"direction", tag.direction)


func _space_out(size: Vector2, inset: float, half: float) -> void:
	var gap := half * 1.3
	for side in [-1.0, 1.0]:
		var column: Array[Tag] = []
		for tag in _live:
			if absf(tag.direction.x) > 0.5 and signf(tag.direction.x) == side:
				column.append(tag)

		column.sort_custom(func(a: Tag, b: Tag) -> bool: return a.position.y < b.position.y)
		for i in range(1, column.size()):
			column[i].drawn.y = maxf(column[i].drawn.y, column[i - 1].drawn.y + gap * (column[i - 1].span + column[i].span) * 0.5)

		var limit := size.y - inset
		for i in range(column.size() - 1, -1, -1):
			column[i].drawn.y = minf(column[i].drawn.y, limit)
			if i > 0:
				limit = column[i].drawn.y - gap * (column[i - 1].span + column[i].span) * 0.5
