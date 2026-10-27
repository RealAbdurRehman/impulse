class_name Door
extends Node3D

const MAX_SPIN := 8.0

static var bodies: Array[RID] = []
static var revision := 0

static var _panels: Array[DoorPanel] = []
static var _bones: Array[PhysicsBody3D] = []

@export var width := 0.96
@export var height := 2.2
@export var thickness := 0.13
@export var mass := 30.0
@export_range(10.0, 170.0) var open_degrees := 100.0
@export var both_ways := true
@export var spring := 3.0
@export var damping := 2.2
@export var push_gain := 1.5
@export var bullet_gain := 15.0
@export var model := "doors/door_1"

var angle := 0.0
var spin := 0.0

var _panel: DoorPanel


static func exempt(bone: PhysicsBody3D) -> void:
	_bones.append(bone)
	for panel in _panels:
		panel.add_collision_exception_with(bone)


func _ready() -> void:
	_panel = DoorPanel.new()
	_panel.door = self
	_panel.set_meta(&"surface", &"wood")
	_panel.set_meta(&"stainless", true)

	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, thickness)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(width * 0.5, height * 0.5, 0.0)
	_panel.add_child(collider)

	var leaf := (load("res://assets/urban/%s.glb" % model) as PackedScene).instantiate() as Node3D
	leaf.scale = Vector3(width, 1.0, 1.0)
	leaf.rotation.y = PI
	for node in leaf.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var material := mesh.surface_get_material(i) as BaseMaterial3D
			material.vertex_color_use_as_albedo = false
			material.metallic = 0.0

	_panel.add_child(leaf)
	_panel.marks = ImpactMarks.new()
	_panel.marks.capacity = 24
	_panel.marks.follow = _panel
	_panel.add_child(_panel.marks)
	add_child(_panel)
	bodies.append(_panel.get_rid())
	_panels.append(_panel)
	revision += 1
	for bone in _bones:
		if is_instance_valid(bone):
			_panel.add_collision_exception_with(bone)

	set_physics_process(false)


func _exit_tree() -> void:
	bodies.erase(_panel.get_rid())
	_panels.erase(_panel)
	revision += 1


func hit(point: Vector3, impulse: Vector3) -> void:
	var r := point - global_position
	spin += (r.z * impulse.x - r.x * impulse.z) * bullet_gain / (mass * width * width / 3.0)
	_wake()


func resists(point: Vector3, velocity: Vector3) -> bool:
	return not both_ways and angle <= 0.0 and _wanted_spin(point, velocity) < 0.0


func shove(point: Vector3, velocity: Vector3) -> void:
	var wanted := _wanted_spin(point, velocity) * push_gain
	if absf(wanted) > absf(spin) or signf(wanted) != signf(spin):
		spin = wanted
		_wake()


func _wanted_spin(point: Vector3, velocity: Vector3) -> float:
	var r := point - global_position
	return (velocity.x * r.z - velocity.z * r.x) / maxf(r.x * r.x + r.z * r.z, 0.04)


func _wake() -> void:
	spin = clampf(spin, -MAX_SPIN, MAX_SPIN)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	var limit := deg_to_rad(open_degrees)
	spin += (-spring * angle - damping * spin) * delta
	angle += spin * delta

	var low := -limit if both_ways else 0.0
	if angle < low:
		angle = low
		spin = maxf(spin, 0.0)
	elif angle > limit:
		angle = limit
		spin = minf(spin, 0.0)

	_panel.rotation.y = angle
	if absf(angle) < 0.002 and absf(spin) < 0.01:
		angle = 0.0
		spin = 0.0
		_panel.rotation.y = 0.0
		set_physics_process(false)
