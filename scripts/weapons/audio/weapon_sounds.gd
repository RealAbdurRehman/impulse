class_name WeaponSounds
extends Resource

@export var fire: SoundSet
@export var dry_fire: SoundSet

@export_group("Slide")
@export var slide_lock: SoundSet
@export var slide_release: SoundSet
@export var rack_back: SoundSet
@export var rack_forward: SoundSet

@export_group("Magazine")
@export var mag_out: SoundSet
@export var mag_in: SoundSet

@export_group("Aiming")
@export var aim_in: SoundSet
@export var aim_out: SoundSet
@export_range(-12.0, 0.0, 0.1) var aim_out_db := -3.0
@export_range(0.5, 1.0, 0.01) var aim_out_pitch := 0.94
@export_range(0.0, 1.0, 0.01) var aim_gap := 0.12

@export_group("Casings")
@export var casing: SoundSet
@export_range(0.5, 20.0, 0.1) var casing_full_speed := 5.0
@export_range(0.0, 5.0, 0.1) var casing_min_speed := 0.6
@export_range(0.0, 1.0, 0.05) var casing_falloff := 0.6
@export_range(0.0, 0.2, 0.005) var casing_gap := 0.03

@export_group("Burst")
@export_range(0.5, 1.5, 0.01) var fire_pitch := 1.0
@export_range(0.0, 3.0, 0.1) var burst_drop_db := 1.0
@export_range(0.0, 12.0, 0.1) var burst_max_drop_db := 4.0
@export_range(0.1, 2.0, 0.05) var burst_reset := 0.6
@export_range(0.02, 1.0, 0.01) var tail_fade := 0.25

@export_group("Body layer")
@export_range(-24.0, 0.0, 0.1) var body_db := -5.0
@export_range(0.5, 1.0, 0.01) var body_pitch := 0.8

@export_group("Mix")
@export_range(-12.0, 0.0, 0.1) var duck_db := -4.0
@export_range(0.0, 1.0, 0.01) var duck_time := 0.25
@export_range(-12.0, 0.0, 0.1) var tactical_db := -3.0
