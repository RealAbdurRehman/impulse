class_name StumpCap
extends RefCounted

const RADIUS := {
	&"Head": 0.075,
	&"Arm": 0.064,
	&"ForeArm": 0.05,
	&"Hand": 0.038,
	&"UpLeg": 0.092,
	&"Leg": 0.07,
	&"Foot": 0.052,
}
const SIDES := 14

static var _flesh: StandardMaterial3D
static var _bone: StandardMaterial3D
static var _cloth: StandardMaterial3D


static func part_of(bone: PhysicalBone3D) -> StringName:
	var name := String(bone.bone_name)
	if name.ends_with("Head"):
		return &"Head"

	if name.ends_with("ForeArm"):
		return &"ForeArm"

	if name.ends_with("Arm"):
		return &"Arm"

	if name.ends_with("Hand"):
		return &"Hand"

	if name.ends_with("UpLeg"):
		return &"UpLeg"

	if name.ends_with("Leg"):
		return &"Leg"

	if name.ends_with("Foot"):
		return &"Foot"

	return &""


static func seat(mesh: MeshInstance3D, top: Vector3, axis: Vector3, reach: float) -> Vector3:
	var low := INF
	for surface in mesh.mesh.get_surface_count():
		var verts: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for v in verts:
			var rel := mesh.global_transform * v - top
			var along := rel.dot(axis)
			if along < -0.25 or along > 0.12:
				continue

			if (rel - axis * along).length() < reach:
				low = minf(low, along)

	return top + axis * (low if low != INF else 0.0)


static func attach(bone: PhysicalBone3D, joint: Vector3, outward: Vector3, radius: float) -> void:
	var up := outward.normalized()
	var side := up.cross(Vector3.BACK if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var placed := Transform3D(Basis(side, up, side.cross(up)), joint)
	var cloth: Color
	if part_of(bone) == &"Hand":
		cloth = (
			(bone.get_node(^"Hand") as MeshInstance3D).material_override as StandardMaterial3D
		).albedo_color
	else:
		cloth = (
			(bone.get_node(^"Look") as MeshInstance3D).mesh.surface_get_material(0)
			as StandardMaterial3D
		).albedo_color

	var cap := MeshInstance3D.new()
	cap.name = &"Stump"
	cap.mesh = _mesh(radius, cloth)
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cap.transform = bone.global_transform.affine_inverse() * placed
	bone.add_child(cap)


static func _mesh(radius: float, cloth: Color) -> ArrayMesh:
	_prepare()
	var u := radius / 0.06
	var fat := Color(0.6, 0.4, 0.32)
	var muscle := Color(0.4, 0.09, 0.07)
	var rings := [
		[-0.03, 0.84, 0.0, Color(0.22, 0.025, 0.03)],
		[0.0, 1.05, 0.04, Color(0.3, 0.035, 0.04)],
		[0.032, 1.0, 0.18, Color(0.42, 0.06, 0.06)],
		[0.058, 0.8, 0.34, Color(0.48, 0.08, 0.07)],
		[0.046, 0.46, 0.14, Color(0.14, 0.01, 0.014)],
	]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var grid: Array = []
	var tones: Array = []
	for ring in rings:
		var row: Array[Vector3] = []
		var colours: Array[Color] = []
		for i in SIDES:
			var angle := TAU * float(i) / float(SIDES)
			var rad := radius * float(ring[1]) * (1.0 + randf_range(-1.0, 1.0) * float(ring[2]))
			var y := (float(ring[0]) + randf_range(-1.0, 1.0) * 0.012 * float(ring[2])) * u
			row.append(Vector3(cos(angle) * rad, y, sin(angle) * rad))
			var base: Color = ring[3]
			var pick := randf()
			var mottled := base * randf_range(0.8, 1.15)
			if float(ring[2]) > 0.2:
				if pick < 0.22:
					mottled = base.lerp(fat, 0.65)
				elif pick < 0.55:
					mottled = base.lerp(muscle, 0.6) * randf_range(0.8, 1.1)
			colours.append(Color(mottled.r, mottled.g, mottled.b))

		grid.append(row)
		tones.append(colours)

	var centre := Vector3(0.0, 0.034 * u, 0.0)
	for r in rings.size() - 1:
		for i in SIDES:
			var j := (i + 1) % SIDES
			_tri(
				st,
				grid[r][i],
				grid[r + 1][j],
				grid[r][j],
				tones[r][i],
				tones[r + 1][j],
				tones[r][j],
			)
			_tri(
				st,
				grid[r][i],
				grid[r + 1][i],
				grid[r + 1][j],
				tones[r][i],
				tones[r + 1][i],
				tones[r + 1][j],
			)

	var last := rings.size() - 1
	for i in SIDES:
		var j := (i + 1) % SIDES
		_tri(
			st,
			grid[last][i],
			centre,
			grid[last][j],
			tones[last][i],
			Color(0.09, 0.004, 0.008),
			tones[last][j],
		)

	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, _flesh)

	var bone := SurfaceTool.new()
	bone.begin(Mesh.PRIMITIVE_TRIANGLES)
	bone.set_smooth_group(0)
	var base_y := centre.y - 0.004 * u
	var top := centre.y + 0.03 * u
	var bone_r := radius * 0.3
	for i in 9:
		var j := (i + 1) % 9
		var a0 := TAU * float(i) / 9.0
		var a1 := TAU * float(j) / 9.0
		var jr0 := bone_r * randf_range(0.85, 1.15)
		var jr1 := bone_r * randf_range(0.85, 1.15)
		var p0 := Vector3(cos(a0) * jr0, base_y, sin(a0) * jr0)
		var p1 := Vector3(cos(a1) * jr1, base_y, sin(a1) * jr1)
		var t0 := Vector3(
			cos(a0) * jr0 * 0.9,
			top + randf_range(0.0, 0.006) * u,
			sin(a0) * jr0 * 0.9,
		)
		var t1 := Vector3(
			cos(a1) * jr1 * 0.9,
			top + randf_range(0.0, 0.006) * u,
			sin(a1) * jr1 * 0.9,
		)
		var ivory := Color(0.66, 0.6, 0.48)
		_tri(bone, p0, t1, p1, ivory, ivory, ivory)
		_tri(bone, p0, t0, t1, ivory, ivory, ivory)
		_tri(
			bone,
			t0,
			Vector3(0.0, top - 0.003 * u, 0.0),
			t1,
			ivory,
			Color(0.32, 0.05, 0.05),
			ivory,
		)

	bone.generate_normals()
	bone.commit(mesh)
	mesh.surface_set_material(1, _bone)

	var rags := SurfaceTool.new()
	rags.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stained := cloth.lerp(Color(0.24, 0.025, 0.025), 0.55)
	for i in 6:
		var a := TAU * (float(i) + randf_range(-0.3, 0.3)) / 6.0
		var span := randf_range(0.25, 0.5)
		var reach := randf_range(0.008, 0.03) * u
		var lean := randf_range(1.12, 1.4)
		var root0 := Vector3(cos(a - span) * radius * 1.0, -0.012 * u, sin(a - span) * radius * 1.0)
		var root1 := Vector3(cos(a + span) * radius * 1.0, -0.012 * u, sin(a + span) * radius * 1.0)
		var tip := Vector3(
			cos(a + randf_range(-0.2, 0.2)) * radius * lean,
			reach,
			sin(a + randf_range(-0.2, 0.2)) * radius * lean,
		)
		_tri(rags, root0, tip, root1, cloth * 0.9, stained, cloth * 0.9)

	rags.generate_normals()
	rags.commit(mesh)
	mesh.surface_set_material(2, _cloth)
	return mesh


static func _tri(
	st: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	ca: Color,
	cb: Color,
	cc: Color,
) -> void:
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)


static func _prepare() -> void:
	if _flesh != null:
		return

	_flesh = StandardMaterial3D.new()
	_flesh.vertex_color_use_as_albedo = true
	_flesh.roughness = 0.78
	_flesh.cull_mode = BaseMaterial3D.CULL_DISABLED
	_flesh.emission_enabled = true
	_flesh.emission = Color(0.25, 0.02, 0.025)
	_flesh.emission_energy_multiplier = 0.08

	_bone = StandardMaterial3D.new()
	_bone.vertex_color_use_as_albedo = true
	_bone.roughness = 0.6
	_bone.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bone.emission_enabled = true
	_bone.emission = Color(0.3, 0.27, 0.2)
	_bone.emission_energy_multiplier = 0.15

	_cloth = StandardMaterial3D.new()
	_cloth.vertex_color_use_as_albedo = true
	_cloth.roughness = 0.9
	_cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
