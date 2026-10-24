class_name WeaponStats
extends Resource

@export_group("Model")
@export var scene: PackedScene

@export var slide_parts: Array[StringName] = [&"Slide", &"Cover"]
@export var barrel_parts: Array[StringName] = [&"Barrel", &"MuzzleNut"]
@export var handle_part: StringName
@export var cover_part: StringName
@export var trigger_part: StringName = &"Trigger"
@export var catch_part: StringName = &"SlideStop"

@export var feed_part: StringName = &"Bullet"
@export var casing_part: StringName = &"BulletCasing"
@export var mag_part: StringName = &"EmptyMag"
@export var spare_mag_part: StringName = &"MagFull"

@export_group("Hold")
@export var main_grip_part: StringName = &"LowerFrame"
@export var main_grip_axis := Vector3.UP
@export_range(-90.0, 90.0) var main_grip_yaw_degrees := 0.0
@export_range(0.0, 0.2) var main_hand_length := 0.0
@export_range(0.0, 0.1) var main_hand_height := 0.05

@export var support_grip_part: StringName = &"LowerFrame"
@export var support_grip_axis := Vector3.UP
@export var support_palm_facing := Vector3.BACK
@export_range(-90.0, 90.0) var support_grip_yaw_degrees := 0.0
@export_range(0.2, 1.0) var support_grip_cover := 1.0
@export var support_grip_drop := 0.0

@export_range(0.0, 1.0) var wrist_follow_main := 0.0
@export_range(0.0, 1.0) var wrist_follow_support := 0.0
@export_range(0.0, 1.0) var wrist_follow_bolt := 1.0
@export_range(-45.0, 45.0) var wrist_bolt_lift_degrees := 0.0
@export var hold_elbow_flare_degrees := -60.0
@export var bolt_elbow_flare_degrees := -60.0
@export var support_elbow_flare_degrees := -60.0
@export_range(0.0, 1.0) var low_aim_raise := 1.0
@export var hold_reach := 0.5
@export var hold_reach_min := 0.15
@export var hold_drop := 0.05
@export var hold_up_forward := 0.0
@export var hold_side := 0.0
@export_range(-45.0, 45.0) var hold_twist_degrees := 0.0
@export_range(-45.0, 45.0) var hold_yaw_degrees := 0.0
@export_range(10.0, 90.0) var aim_up_limit_degrees := 80.0
@export_range(10.0, 90.0) var aim_down_limit_degrees := 70.0

@export_group("Fire")
@export var automatic := true
@export var auto_reload := false

@export var reload_time := 2.4
@export var magazine_size := 17
@export var trigger_buffer := 0.12

@export_range(30.0, 1500.0, 1.0) var rounds_per_minute := 300.0

@export_group("Action")
@export var manual_cycle := false
@export var auto_cycle := false

@export var cycle_back_time := 0.16
@export var cycle_forward_time := 0.2
@export_range(0.05, 1.0) var cycle_eject_at := 0.85
@export_range(0.0, 1.0) var cycle_jolt := 0.0
@export var cycle_settle_time := 0.0

@export_group("Bolt action")
@export_range(0.0, 140.0) var bolt_lift_degrees := 0.0
@export var bolt_reach_time := 0.2
@export var bolt_lift_time := 0.13
@export var bolt_pause_time := 0.04
@export var bolt_lower_time := 0.13
@export var bolt_return_time := 0.22
@export var bolt_hand_offset := Vector3.ZERO
@export_range(-90.0, 90.0) var bolt_hand_turn_degrees := 0.0
@export var bolt_hand_arc := Vector3(0.0, 0.03, 0.02)
@export var chamber_after_reload := false
@export var ads_breaks_on_cycle := false

@export_group("Selector")
@export var selector_part: StringName
@export_range(-180.0, 180.0) var selector_degrees := 90.0
@export_range(0.1, 2.0) var selector_time := 0.3
@export_range(0.0, 1.0) var selector_jolt := 0.35
@export var selector_hand_turn_degrees := Vector3.ZERO

@export_group("Aim down sights")
@export var ads_time := 0.24
@export var ads_eye_distance := 0.22
@export_range(-45.0, 45.0) var ads_yaw_degrees := 0.0
@export var ads_zoom := 0.9
@export_range(1.0, 5.0, 0.05) var ads_look := 1.0
@export var ads_move_scale := 0.55
@export_range(0.0, 1.0) var ads_spread_scale := 0.3
@export_range(0.0, 1.0) var ads_recoil_scale := 0.7

@export_group("Ballistics")
@export var damage := 25.0
@export var max_range := 60.0

@export var pellets := 1
@export var impact_impulse := 1.0

@export_range(0.01, 3.0, 0.01) var penetration := 0.3

@export_flags_3d_physics var hit_mask := 3

@export_range(0.0, 20.0, 0.1) var spread_degrees := 0.5
@export_range(0.0, 1.0, 0.05) var pellet_jitter := 0.7

@export var falloff_start := 0.0
@export var falloff_end := 0.0
@export_range(0.0, 1.0, 0.05) var falloff_floor := 0.3

@export_range(0.0, 2.0, 0.01) var bloom_per_shot := 0.0
@export_range(0.0, 20.0, 0.1) var bloom_max := 3.0
@export_range(0.1, 30.0, 0.1) var bloom_recovery := 6.0

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
@export var barrel_smoke_lifetime := 3.2

@export var barrel_cool_time := 3.0
@export var barrel_heat_per_shot := 0.025

@export_range(0.0, 1.0) var barrel_smoke_opacity := 0.65

@export_group("Tracer")
@export var tracer_speed := 150.0

@export var tracer_length := 2.0
@export var tracer_width := 0.055
@export_range(0.0, 1.0, 0.05) var tracer_variation := 0.0

@export var tracer_color := Color(1.0, 0.97, 0.85)
@export var tracer_glow_color := Color(1.0, 0.55, 0.22)

@export_group("Casing")
@export var eject_casings := true

@export var casing_scale := 1.0
@export var eject_velocity := Vector3(-0.8, 2.4, 1.6)

@export var eject_spin := 30.0
@export var casing_lifetime := 8.0

@export_range(0.0, 1.0) var eject_jitter := 0.3

@export_group("Recoil")
@export var recoil_slide := 0.03

@export var recoil_hips_back := 0.035
@export var recoil_hips_drop := 0.02

@export var recoil_push := 0.04

@export_range(0.0, 50.0, 0.1) var recoil_flip_degrees := 20.0
@export_range(0.0, 10.0, 0.1) var recoil_torso_degrees := 6.0
@export_range(60.0, 140.0, 1.0) var recoil_flip_ceiling_degrees := 90.0

@export_range(0.0, 3.0, 0.05) var recoil_climb_degrees := 0.0
@export_range(0.5, 10.0, 0.1) var recoil_climb_recovery := 3.0

@export_range(1.0, 20.0, 0.1) var recoil_flip_hz := 4.5
@export_range(0.1, 0.95) var recoil_flip_damping := 0.62

@export_range(1.0, 20.0, 0.1) var recoil_slide_hz := 5.4
@export_range(0.1, 0.95) var recoil_slide_damping := 0.6

@export_range(0.5, 10.0, 0.1) var recoil_body_hz := 1.75
@export_range(0.1, 0.95) var recoil_body_damping := 0.5

@export_range(0.0, 1.0) var recoil_variation := 0.5
@export_range(1.0, 4.0, 0.1) var recoil_stacking := 2.0

@export_range(0.0, 1.0) var recoil_aim_influence := 1.0

@export_group("Camera")
@export var camera_kick := 0.05
@export_range(0.0, 1.0, 0.01) var camera_shake := 0.12

@export_group("Slide")
@export var slide_travel := 0.05
@export var slide_back_time := 0.03
@export var slide_forward_time := 0.065
@export var slide_release_time := 0.045

@export var slide_lock := true
@export_range(0.5, 1.0) var slide_lock_hold := 0.93

@export var barrel_travel := 0.008
@export var barrel_tilt_degrees := 2.0

@export var slide_stop_degrees := 8.0
@export var cover_degrees := 177.0
@export var trigger_pull_degrees := 22.0

@export_group("Reload")
@export var mag_hold_proud := 0.0
@export_range(0.0, 1.0) var rack_start := 0.45
@export_range(0.0, 1.0) var rack_pull := 1.0

@export_group("Shell reload")
@export var reload_by_shell := false
@export var shell_time := 0.6
@export var shell_return_time := 0.5
@export var shell_release_time := 0.45

@export_group("Audio")
@export var sounds: WeaponSounds
