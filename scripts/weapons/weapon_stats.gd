class_name WeaponStats
extends Resource

@export var display_name := "Glock 17"

@export_group("Fire")
@export var automatic := false
@export var auto_reload := true

@export var reload_time := 1.6
@export var magazine_size := 17
@export var trigger_buffer := 0.12

@export_range(30.0, 1500.0, 1.0) var rounds_per_minute := 600.0

@export_group("Ballistics")
@export var damage := 25.0
@export var max_range := 60.0

@export var pellets := 1
@export var impact_impulse := 1.0

@export_flags_3d_physics var hit_mask := 3

@export_range(0.0, 20.0, 0.1) var spread_degrees := 0.5

@export_group("Muzzle flash")
@export var flash_length := 0.3
@export var flash_width := 0.11
@export var flash_duration := 0.05

@export var light_energy := 0.1
@export var light_range := 2.2
@export var flash_color := Color(1.0, 0.55, 0.38)

@export_range(0.0, 1.0) var flash_glow := 0.12

@export_group("Smoke")
@export var smoke_size := 1.0
@export var smoke_speed := 1.5
@export var smoke_lifetime := 1.6

@export var smoke_color := Color(0.7, 0.74, 0.82)

@export_range(0.0, 1.0) var smoke_opacity := 0.28

@export_group("Barrel smoke")
@export var barrel_smoke_size := 0.13
@export var barrel_smoke_rise := 0.14
@export var barrel_smoke_lifetime := 1.6

@export var barrel_cool_time := 3.0
@export var barrel_heat_per_shot := 0.15

@export_range(0.0, 1.0) var barrel_smoke_opacity := 0.65

@export_group("Tracer")
@export var tracer_speed := 150.0

@export var tracer_length := 2.0
@export var tracer_width := 0.055

@export var tracer_color := Color(1.0, 0.97, 0.85)
@export var tracer_glow_color := Color(1.0, 0.55, 0.22)

@export_range(0.0, 1.0) var tracer_chance := 1.0

@export_group("Casing")
@export var eject_casings := true

@export var casing_scale := 1.0
@export var eject_offset := Vector3(-0.1, 0.005, 0.013)

@export var eject_velocity := Vector3(-0.8, 2.4, 1.6)

@export var eject_spin := 30.0
@export var casing_lifetime := 8.0

@export_range(0.0, 1.0) var eject_jitter := 0.3

@export_group("Recoil")
@export var recoil_slide := 0.03

@export var recoil_hips_back := 0.035
@export var recoil_hips_drop := 0.02

@export var recoil_push := 0.04

@export_range(0.0, 20.0, 0.1) var recoil_flip_degrees := 15.0
@export_range(0.0, 10.0, 0.1) var recoil_torso_degrees := 6.0

@export_range(0.0, 1.0) var recoil_variation := 0.0
@export_range(1.0, 4.0, 0.1) var recoil_stacking := 2.0

@export_range(0.0, 1.0) var recoil_aim_influence := 1.0
