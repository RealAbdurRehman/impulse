class_name ExitZone
extends Node3D

signal completed

@export var target: CharacterMovement
@export var size := Vector3(3.0, 3.0, 4.0)
@export var hold_time := 5.0

var held := 0.0


func _ready() -> void:
	_add_slab(size, size.y * 0.5, 0.07)
	_add_slab(Vector3(size.x, 0.03, size.z), 0.02, 0.3)


func _physics_process(delta: float) -> void:
	var offset := target.global_position - global_position
	var inside := absf(offset.x) <= size.x * 0.5 and offset.y > -0.5 and offset.y < size.y
	if inside and target.health.alive:
		held += delta / maxf(Engine.time_scale, 0.05)
	else:
		held = 0.0

	if held >= hold_time:
		set_physics_process(false)
		completed.emit()


func _add_slab(extent: Vector3, height: float, alpha: float) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(0.93, 0.93, 0.9, alpha)

	var mesh := BoxMesh.new()
	mesh.size = extent

	var slab := MeshInstance3D.new()
	slab.mesh = mesh
	slab.material_override = material
	slab.position.y = height
	slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(slab)
