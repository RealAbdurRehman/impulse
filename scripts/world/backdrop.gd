class_name Backdrop
extends RefCounted

const FRONT := -13.0
const MARGIN := 70.0
const PIECES := {
	"buildings/building_small_1": Vector3(-7.23, 5.23, 2.31),
	"buildings/building_medium_2_001": Vector3(-7.53, 7.53, 0.57),
	"buildings/building_large_2": Vector3(-9.32, 11.32, 0.32),
}

static var _asphalt: StandardMaterial3D


static func build(level: Node3D, from: float, to: float, rng: RandomNumberGenerator) -> void:
	var holder := Node3D.new()
	holder.name = &"Backdrop"
	level.add_child(holder)
	_ground(holder, from - MARGIN, to + MARGIN)
	_skyline(holder, from - MARGIN, to + MARGIN, rng)
	var far := Batch.new()
	far.row("sidewalks/sidewalk_straight_3m", from - MARGIN, to + MARGIN, -11.5, PI)
	far.commit(holder)
	_atmosphere((level.get_node("WorldEnvironment") as WorldEnvironment).environment)


static func asphalt() -> StandardMaterial3D:
	if _asphalt == null:
		_asphalt = StandardMaterial3D.new()
		_asphalt.albedo_texture = load("res://assets/urban/textures/t_concrete_asphalt_basecolor.png")
		_asphalt.albedo_color = Color(0.62, 0.62, 0.66)
		_asphalt.uv1_triplanar = true
		_asphalt.uv1_scale = Vector3.ONE * 0.18
		_asphalt.roughness = 1.0

	return _asphalt


static func _ground(parent: Node3D, from: float, to: float) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(to - from, 70.0)

	var ground := MeshInstance3D.new()
	ground.mesh = mesh
	ground.material_override = asphalt()
	ground.position = Vector3((from + to) * 0.5, -0.15, -22.0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ground)


static func _skyline(parent: Node3D, from: float, to: float, rng: RandomNumberGenerator) -> void:
	var names := PIECES.keys()
	var x := from
	var last := -1
	while x < to:
		var pick := rng.randi_range(0, names.size() - 1)
		if pick == last:
			pick = (pick + 1) % names.size()

		last = pick
		var extent: Vector3 = PIECES[names[pick]]
		var mirror := rng.randf() < 0.5
		var origin := x + extent.y if mirror else x - extent.x
		Kit.urban(parent, names[pick], Vector3(origin, 0.0, FRONT - extent.z), 0.0, Vector3(-1.0 if mirror else 1.0, 1.0, 1.0))
		x += extent.y - extent.x


static func _atmosphere(env: Environment) -> void:
	var haze := Color(0.66, 0.69, 0.72)
	env.fog_enabled = true
	env.fog_light_color = haze
	env.fog_density = 0.007
	env.fog_sky_affect = 1.0
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	sky.ground_horizon_color = haze
	sky.ground_bottom_color = haze.darkened(0.15)
