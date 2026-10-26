class_name BloodWorld
extends Node3D

static var _current: BloodWorld

var clock := 0.0
var stains: BloodStains
var drops: BloodDrops
var mist: BloodMist
var gibs: Gibs


static func of(node: Node) -> BloodWorld:
	if not is_instance_valid(_current) or not _current.is_inside_tree():
		_current = BloodWorld.new()
		_current.name = &"BloodWorld"
		node.get_tree().current_scene.add_child(_current)

	return _current


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	stains = BloodStains.new()
	stains.name = &"Stains"
	add_child(stains)

	drops = BloodDrops.new()
	drops.name = &"Drops"
	drops.stains = stains
	add_child(drops)

	mist = BloodMist.new()
	mist.name = &"Mist"
	add_child(mist)

	gibs = Gibs.new()
	gibs.name = &"Gibs"
	add_child(gibs)

	_warm_up()


func _warm_up() -> void:
	var overlay := ShaderMaterial.new()
	overlay.shader = Bleeding.BODY_SHADER
	var clear := StandardMaterial3D.new()
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	var probe := MeshInstance3D.new()
	probe.mesh = BoxMesh.new()
	probe.material_override = clear
	probe.material_overlay = overlay
	probe.extra_cull_margin = 16384.0
	probe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(probe)

	stains.warm(true)
	drops.warm(true)
	mist.warm(true)
	for i in 3:
		await get_tree().process_frame

	stains.warm(false)
	drops.warm(false)
	mist.warm(false)
	probe.queue_free()


func _process(delta: float) -> void:
	clock += delta
	stains.set_clock(clock)
	drops.clock = clock
	get_tree().call_group(&"bleeding", &"tick", clock)


func jet(
	origin: Vector3,
	direction: Vector3,
	count: int,
	speed: Vector2,
	spread: float,
	size: Vector2,
	inherit := Vector3.ZERO,
	wall := 0.5,
) -> void:
	for i in count:
		var heavy := pow(randf(), 2.2)
		var dir := _cone(direction, spread)
		dir.z -= randf() * wall
		dir = dir.normalized()
		var vel := dir * lerpf(speed.y, speed.x, heavy) * randf_range(0.8, 1.0) + inherit
		drops.spawn(origin + dir * randf() * 0.03, vel, lerpf(size.x, size.y, heavy))


func wall_spatter(origin: Vector3, direction: Vector3, count: int) -> void:
	for i in count:
		var glance := randf_range(0.6, 1.4) if randf() < 0.25 else randf_range(-0.2, 0.45)
		var dir := Vector3(direction.x * glance, randf_range(-0.3, 0.45), -1.0).normalized()
		drops.spawn(origin, dir * randf_range(4.5, 8.5), lerpf(0.005, 0.018, pow(randf(), 2.0)))

	for i in count * 3:
		var dir := Vector3(direction.x * randf_range(-0.3, 0.6), randf_range(-0.4, 0.6), -1.0).normalized()
		drops.spawn(origin, dir * randf_range(5.0, 9.0), randf_range(0.003, 0.006))


func cloud(
	origin: Vector3,
	direction: Vector3,
	size: float,
	puffs: int,
	life: float,
	speed: float,
	density: float,
) -> void:
	for i in puffs:
		var dir := _cone(direction, 0.55)
		var at := origin + dir * randf() * size * 0.35
		at.z += 0.25
		mist.puff(
			at,
			dir * speed * randf_range(0.5, 1.0),
			size * 0.35,
			size * randf_range(0.9, 1.4),
			life * randf_range(0.8, 1.2),
			density * randf_range(0.7, 1.0),
		)


func _cone(direction: Vector3, spread: float) -> Vector3:
	direction = direction.normalized()
	var perp := direction.cross(Vector3.BACK if absf(direction.z) < 0.9 else Vector3.UP).normalized()
	return direction.rotated(perp, spread * sqrt(randf())).rotated(direction, randf() * TAU)
