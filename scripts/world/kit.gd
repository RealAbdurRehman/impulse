class_name Kit
extends RefCounted

const URBAN := "res://assets/urban/%s.glb"
const NATURE := "res://assets/nature/%s.glb"
const TREES := [
	"trees/commontree_1",
	"trees/commontree_2",
	"trees/commontree_3",
	"trees/commontree_4",
	"trees/commontree_5",
	"trees/pine_1",
	"trees/pine_2",
	"trees/pine_3",
	"trees/pine_4",
	"trees/pine_5",
]
const SHRUBS := ["plants/bush_common_flowers", "plants/fern_1"]
const TUFTS := ["grass/grass_common_short", "grass/grass_common_tall", "grass/grass_wispy_short", "plants/clover_1"]
const ROCKS := ["rocks/rock_medium_1", "rocks/rock_medium_2", "rocks/rock_medium_3"]

static var _concrete: StandardMaterial3D
static var _grass: StandardMaterial3D


static func urban(parent: Node3D, name: String, at: Vector3, yaw := 0.0, size := Vector3.ONE) -> Node3D:
	return _place(parent, URBAN % name, at, yaw, size)


static func nature(parent: Node3D, name: String, at: Vector3, yaw := 0.0, size := Vector3.ONE) -> Node3D:
	return _place(parent, NATURE % name, at, yaw, size)


static func solid(parent: Node3D, extent: Vector3, at: Vector3, surface: StringName) -> StaticBody3D:
	var shape := BoxShape3D.new()
	shape.size = extent

	var collider := CollisionShape3D.new()
	collider.shape = shape

	var body := StaticBody3D.new()
	body.position = at
	body.set_meta(&"surface", surface)
	body.add_child(collider)
	parent.add_child(body)
	return body


static func concrete(parent: Node3D, extent: Vector3, at: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = extent

	var slab := MeshInstance3D.new()
	slab.mesh = mesh
	slab.material_override = concrete_material()
	slab.position = at
	parent.add_child(slab)


static func grass(parent: Node3D, extent: Vector3, at: Vector3) -> void:
	if _grass == null:
		_grass = StandardMaterial3D.new()
		_grass.albedo_color = Color(0.3, 0.42, 0.2)
		_grass.roughness = 1.0

	var mesh := BoxMesh.new()
	mesh.size = extent

	var lawn := MeshInstance3D.new()
	lawn.mesh = mesh
	lawn.material_override = _grass
	lawn.position = at
	parent.add_child(lawn)


static func staircase(parent: Node3D, at: Vector3, run: float, rise: float, count: int, near: float, far: float) -> void:
	var tread := run / count
	var lift := rise / count
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in count:
		var x0 := tread * i
		var x1 := x0 + tread
		var top := lift * (i + 1)
		_quad(tool, Vector3.LEFT, Vector3(x0, top - lift, near), Vector3(x0, top - lift, far), Vector3(x0, top, far), Vector3(x0, top, near))
		_quad(tool, Vector3.UP, Vector3(x0, top, near), Vector3(x0, top, far), Vector3(x1, top, far), Vector3(x1, top, near))
		_quad(tool, Vector3.BACK, Vector3(x0, 0.0, near), Vector3(x1, 0.0, near), Vector3(x1, top, near), Vector3(x0, top, near))
		_quad(tool, Vector3.FORWARD, Vector3(x1, 0.0, far), Vector3(x0, 0.0, far), Vector3(x0, top, far), Vector3(x1, top, far))

	_quad(tool, Vector3.RIGHT, Vector3(run, 0.0, far), Vector3(run, 0.0, near), Vector3(run, rise, near), Vector3(run, rise, far))

	var mesh := MeshInstance3D.new()
	mesh.mesh = tool.commit()
	mesh.material_override = concrete_material()
	mesh.position = at
	parent.add_child(mesh)


static func steps(parent: Node3D, at: Vector3, run: float, rise: float, count: int, near: float, far: float) -> StaticBody3D:
	var tread := run / count
	var lift := rise / count
	var body := StaticBody3D.new()
	body.position = at
	body.set_meta(&"surface", &"flesh")
	body.set_meta(&"stainless", true)

	for i in count:
		var shape := BoxShape3D.new()
		shape.size = Vector3(tread, lift * (i + 1), near - far)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = Vector3(tread * (i + 0.5), lift * (i + 1) * 0.5, (near + far) * 0.5)
		body.add_child(collider)

	parent.add_child(body)
	return body


static func handrail(parent: Node3D, from: Vector3, to: Vector3, height := 0.9) -> void:
	var run := to - from
	var length := Vector2(run.x, run.y).length()
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.13, 0.14, 0.16)
	steel.metallic = 0.3
	steel.roughness = 0.55
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var bar := BoxMesh.new()
	bar.size = Vector3(length, 0.045, 0.045)
	tool.append_from(bar, 0, Transform3D(Basis(Vector3.BACK, atan2(run.y, run.x)), Vector3(run.x * 0.5, run.y * 0.5 + height, 0.0)))

	var post := BoxMesh.new()
	post.size = Vector3(0.035, height, 0.035)
	var count := maxi(roundi(run.x / 0.6), 1)
	for i in count + 1:
		var x := run.x * i / count
		tool.append_from(post, 0, Transform3D(Basis.IDENTITY, Vector3(x, run.y * i / count + height * 0.5, 0.0)))

	var rail := MeshInstance3D.new()
	rail.mesh = tool.commit()
	rail.material_override = steel
	rail.position = from
	parent.add_child(rail)


static func rock(parent: Node3D, name: String, at: Vector3, yaw: float, size: float) -> void:
	nature(parent, name, at, yaw, Vector3.ONE * size)
	solid(parent, Vector3(2.4, 1.7, 2.2) * size, at + Vector3(0.0, 0.85 * size, 0.3 * size), &"dirt")


static func _place(parent: Node3D, path: String, at: Vector3, yaw: float, size: Vector3) -> Node3D:
	var node := (load(path) as PackedScene).instantiate() as Node3D
	node.position = at
	node.rotation.y = yaw
	node.scale = size
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			(mesh.get_active_material(i) as BaseMaterial3D).vertex_color_use_as_albedo = false

	parent.add_child(node)
	return node


static func concrete_material() -> StandardMaterial3D:
	if _concrete == null:
		_concrete = StandardMaterial3D.new()
		_concrete.albedo_texture = load("res://assets/urban/textures/t_concrete_basecolor.png")
		_concrete.uv1_triplanar = true
		_concrete.uv1_scale = Vector3.ONE * 0.4
		_concrete.roughness = 0.95

	return _concrete


static func _quad(tool: SurfaceTool, normal: Vector3, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var order := [a, b, c, a, c, d]
	if (b - a).cross(c - a).dot(normal) > 0.0:
		order = [a, c, b, a, d, c]

	for corner in order:
		tool.set_normal(normal)
		tool.add_vertex(corner)
