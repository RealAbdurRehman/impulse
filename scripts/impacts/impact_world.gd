class_name ImpactWorld
extends Node3D

static var _current: ImpactWorld

@export var puff_cone := 0.85
@export var chip_cone := 0.9

var dust: ImpactDust
var debris: ImpactDebris
var marks: ImpactMarks
var audio: ImpactAudio


static func of(node: Node) -> ImpactWorld:
	if not is_instance_valid(_current) or not _current.is_inside_tree():
		_current = ImpactWorld.new()
		_current.name = &"ImpactWorld"
		node.get_tree().current_scene.add_child(_current)

	return _current


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	marks = ImpactMarks.new()
	marks.name = &"Marks"
	add_child(marks)

	dust = ImpactDust.new()
	dust.name = &"Dust"
	add_child(dust)

	debris = ImpactDebris.new()
	debris.name = &"Debris"
	add_child(debris)

	audio = ImpactAudio.new()
	audio.name = &"Audio"
	add_child(audio)

	_warm_up()


func _warm_up() -> void:
	marks.warm(true)
	dust.warm(true)
	debris.warm(true)
	for i in 3:
		await get_tree().process_frame

	marks.warm(false)
	dust.warm(false)
	debris.warm(false)


func strike(point: Vector3, normal: Vector3, dir: Vector3, surface: StringName, size: float, exiting := false, tint := Color.WHITE) -> void:
	var style := Surfaces.style(surface)
	var dust_color := style.dust_color
	var chip_colors := style.debris_colors
	var mark_color := style.mark_color
	if style.tinted:
		dust_color = tint.lerp(Color.WHITE, 0.4)
		chip_colors = [tint, tint.darkened(0.12), tint.lightened(0.12)]
		mark_color = tint

	if style.sound != null:
		audio.play(style.sound, point, 0.0)

	var punch := pow(size, 0.75)
	var glance := 1.0 - absf(dir.dot(normal))
	var skid := dir - normal * (2.0 * dir.dot(normal))
	var ricochet := not exiting and glance > style.ricochet
	var lean := skid if not exiting else dir
	var spray := (normal + lean * glance * 1.2).normalized()
	var carried := style.dust_forward

	for i in _count(style.dust_count * size):
		var d := _cone(spray, puff_cone)
		d.z = 0.0
		d = d.normalized()
		var speed := randf_range(style.dust_speed.x, style.dust_speed.y) * punch
		dust.puff(point - normal * 0.01, d * speed + dir * carried * speed, style, punch, dust_color)

	for i in _count(style.debris_count * size):
		var d := _cone((spray + dir * carried).normalized(), chip_cone)
		var speed := randf_range(style.debris_speed.x, style.debris_speed.y) * punch
		debris.chip(point + normal * 0.012, d * speed, style, style.debris_glass, chip_colors)

	var sparks := style.spark_count * size
	if ricochet:
		sparks = sparks * 2.0 + 3.0

	var spark_dir := skid if ricochet else spray
	for i in _count(sparks):
		var d := _cone(spark_dir, 0.5 if ricochet else 1.1)
		var speed := randf_range(style.spark_speed.x, style.spark_speed.y) * punch
		debris.spark(point + normal * 0.01, d * speed, style.spark_color, randf_range(0.005, 0.01), randf_range(0.14, 0.32))

	if style.flash > 0.0:
		debris.flash(point + normal * 0.02, style.spark_color.lightened(0.4), 0.07 * style.flash * punch)

	if style.mark != SurfaceStyle.Mark.NONE:
		marks.mark(point, normal, dir, style, size * (1.3 if exiting else 1.0), mark_color)


func _count(amount: float) -> int:
	return int(amount * randf_range(0.8, 1.2) + randf())


func _cone(direction: Vector3, spread: float) -> Vector3:
	direction = direction.normalized()
	var perp := direction.cross(Vector3.BACK if absf(direction.z) < 0.9 else Vector3.UP).normalized()
	return direction.rotated(perp, spread * sqrt(randf())).rotated(direction, randf() * TAU)
