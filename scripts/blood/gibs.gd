class_name Gibs
extends Node3D

@export var capacity := 26
@export var layer := 0
@export_flags_3d_physics var surfaces := 1

static var _flesh: Array[StandardMaterial3D] = []
static var _bone: StandardMaterial3D

var _bodies: Array[RigidBody3D] = []
var _shape := BoxShape3D.new()


func _ready() -> void:
	_shape.size = Vector3(0.05, 0.022, 0.04)
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func burst(origin: Vector3, direction: Vector3, count: int, speed: Vector2) -> void:
	_prepare()
	var dir := direction.normalized()
	for i in count:
		var body := _make(i % 9 == 8)
		add_child(body)
		body.global_position = origin + Vector3(randf_range(-0.03, 0.03), randf_range(-0.03, 0.03), 0.0)
		var spread := dir.rotated(Vector3.BACK, randf_range(-0.9, 0.9))
		body.linear_velocity = spread * randf_range(speed.x, speed.y) + Vector3(0.0, randf_range(0.5, 2.5), randf_range(-1.0, 1.0))
		body.angular_velocity = Vector3(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
		_bodies.append(body)

	while _bodies.size() > capacity:
		_bodies.pop_front().queue_free()


func _make(shard: bool) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.collision_layer = layer
	body.collision_mask = surfaces
	body.mass = 0.12
	body.linear_damp = 0.25
	body.angular_damp = 0.6
	body.contact_monitor = true
	body.max_contacts_reported = 1
	body.body_entered.connect(_plop.bind(body), CONNECT_ONE_SHOT)
	var feel := PhysicsMaterial.new()
	feel.friction = 0.9
	feel.bounce = 0.1
	body.physics_material_override = feel

	var collider := CollisionShape3D.new()
	collider.shape = _shape
	body.add_child(collider)

	var look := MeshInstance3D.new()
	look.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if shard:
		var box := BoxMesh.new()
		box.size = Vector3(randf_range(0.006, 0.01), randf_range(0.02, 0.035), randf_range(0.005, 0.008))
		look.mesh = box
		look.material_override = _bone
	else:
		var lump := SphereMesh.new()
		var size := randf_range(0.01, 0.024)
		lump.radius = size
		lump.height = size * randf_range(0.7, 1.4)
		lump.radial_segments = 5
		lump.rings = 3
		look.mesh = lump
		look.scale = Vector3(randf_range(0.7, 1.5), randf_range(0.5, 1.1), randf_range(0.7, 1.3))
		look.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		look.material_override = _flesh[randi() % _flesh.size()]

	body.add_child(look)
	return body


func _plop(_other: Node, body: RigidBody3D) -> void:
	body.linear_damp = 12.0
	body.angular_damp = 40.0
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(body):
		body.freeze = true


static func _prepare() -> void:
	if _bone != null:
		return

	for tint in [Color(0.26, 0.02, 0.025), Color(0.34, 0.04, 0.045), Color(0.48, 0.22, 0.18), Color(0.17, 0.012, 0.016), Color(0.3, 0.03, 0.035)]:
		var material := StandardMaterial3D.new()
		material.albedo_color = tint
		material.roughness = 0.6
		material.emission_enabled = true
		material.emission = tint
		material.emission_energy_multiplier = 0.12
		_flesh.append(material)

	_bone = StandardMaterial3D.new()
	_bone.albedo_color = Color(0.66, 0.6, 0.48)
	_bone.roughness = 0.6
	_bone.emission_enabled = true
	_bone.emission = Color(0.3, 0.27, 0.2)
	_bone.emission_energy_multiplier = 0.08
