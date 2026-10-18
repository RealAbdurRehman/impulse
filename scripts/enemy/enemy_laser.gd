class_name EnemyLaser
extends RefCounted
## The red line a sniper paints on its target before it shoots. A shot from far
## outside the picture is only fair if the player can see it coming: the line
## crosses the screen, and gets brighter, well before the bullet does.

const THICKNESS := 0.012

var _mesh := MeshInstance3D.new()
var _material := StandardMaterial3D.new()


func _init(parent: Node3D) -> void:
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_mesh.mesh = BoxMesh.new()
	_mesh.material_override = _material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.top_level = true
	_mesh.visible = false
	parent.add_child.call_deferred(_mesh)


## Draws the line from `from` along `dir` for `length` metres; `strength` 0 to 1
## is how long it has been painting.
func show_beam(from: Vector3, dir: Vector3, length: float, strength: float) -> void:
	var up := Vector3(-dir.y, dir.x, 0.0)
	_mesh.global_transform = Transform3D(
		Basis(dir * length, up * THICKNESS, Vector3.BACK * THICKNESS),
		from + dir * length * 0.5,
	)
	_material.albedo_color = Color(1.0, 0.1, 0.08, lerpf(0.25, 0.9, strength))
	_mesh.visible = true


func hide() -> void:
	_mesh.visible = false
