class_name StageLights
extends Node3D

const SKIP_SURFACES := 0xFFFFD

@export var half_length := 200.0
@export var spacing := 28.0
@export var height := 30.0
@export var lane_z := 1.0
@export_range(5.0, 80.0) var cone := 30.0
@export var color := Color(0.88, 0.91, 1.0)
@export var energy := 4.5


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	var housing := StandardMaterial3D.new()
	housing.albedo_color = Color(0.1, 0.1, 0.11)
	housing.roughness = 0.6
	var lens := StandardMaterial3D.new()
	lens.albedo_color = Color(0.9, 0.93, 1.0)
	lens.emission_enabled = true
	lens.emission = color
	lens.emission_energy_multiplier = 2.5

	var kit := MeshKit.new()
	kit.add(housing, MeshKit.box(Vector3(2.6, 0.3, 1.4), 0.06, 2))
	kit.add(lens, MeshKit.box(Vector3(2.2, 0.04, 1.0), 0.015, 1), Transform3D(Basis.IDENTITY, Vector3(0.0, -0.16, 0.0)))

	var count := int(half_length / spacing) * 2 + 1
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = kit.build()
	multi.instance_count = count

	var down := Basis(Vector3.RIGHT, -PI * 0.5)
	for i in count:
		var x := (i - count / 2) * spacing
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(x, height - 0.15, lane_z)))

		var spot := SpotLight3D.new()
		spot.light_color = color
		spot.light_energy = energy
		spot.light_cull_mask = SKIP_SURFACES
		spot.spot_range = height * 1.6
		spot.spot_angle = cone
		spot.spot_angle_attenuation = 1.2
		spot.spot_attenuation = 0.5
		spot.basis = down
		spot.position = Vector3(x, height - 0.3, lane_z)
		add_child(spot)

	var fixtures := MultiMeshInstance3D.new()
	fixtures.multimesh = multi
	fixtures.layers = 2
	fixtures.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fixtures)
