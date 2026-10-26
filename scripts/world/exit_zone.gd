class_name ExitZone
extends Node3D

signal completed

@export var target: CharacterMovement
@export var size := Vector3(3.0, 3.0, 4.0)
@export var hold_time := 5.0

var held := 0.0
var done := false


func _ready() -> void:
	var tint := StandardMaterial3D.new()
	tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tint.cull_mode = BaseMaterial3D.CULL_DISABLED
	tint.albedo_color = Color(0.93, 0.93, 0.9, 0.07)

	var volume := BoxMesh.new()
	volume.size = size
	var body := MeshInstance3D.new()
	body.mesh = volume
	body.material_override = tint
	body.position.y = size.y * 0.5
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)

	var strip := BoxMesh.new()
	strip.size = Vector3(size.x, 0.03, size.z)
	var line := tint.duplicate() as StandardMaterial3D
	line.albedo_color = Color(0.93, 0.93, 0.9, 0.3)
	var ground := MeshInstance3D.new()
	ground.mesh = strip
	ground.material_override = line
	ground.position.y = 0.02
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


func remaining() -> float:
	return hold_time - held


func inside() -> bool:
	var offset := target.global_position - global_position
	return absf(offset.x) <= size.x * 0.5 and offset.y > -0.5 and offset.y < size.y


func _physics_process(delta: float) -> void:
	if done:
		return

	if inside() and target.health.alive:
		held += delta / maxf(Engine.time_scale, 0.05)
	else:
		held = 0.0

	if held >= hold_time:
		done = true
		completed.emit()
