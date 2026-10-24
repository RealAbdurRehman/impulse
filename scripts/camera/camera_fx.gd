class_name CameraFx
extends Node


class Follow:
	var x := 0.0
	var v := 0.0

	func step(goal: float, omega: float, delta: float) -> float:
		var shift := x - goal
		var carry := v + omega * shift
		var decay := exp(-omega * delta)

		x = goal + (shift + carry * delta) * decay
		v = (v - omega * carry * delta) * decay

		return x


@export var target: CharacterMovement

@export_range(0.0, 2.0) var intensity := 1.0

@export_group("Shake")
@export var shake_move := Vector2(0.12, 0.09)
@export var shake_roll_degrees := 1.2
@export var shake_hz := 6.0
@export var shake_smoothing_hz := 7.0
@export var shake_attack := 18.0
@export var trauma_decay := 1.2

@export_group("Recoil kick")
@export var kick_hz := 4.5
@export_range(0.1, 0.95) var kick_damping := 0.85
@export var kick_limit := 0.35
@export_range(0.0, 1.0) var kick_variation := 0.15
@export_range(0.0, 1.0) var kick_lift := 0.3
@export var kick_roll_degrees_per_meter := 3.0
@export var kick_punch_per_meter := 0.06
@export var smoothing_hz := 5.5

@export_group("Hit")
@export var hit_kick := 0.1
@export var hit_shake := 0.2
@export var hit_punch := 0.02
@export var hit_roll_degrees := 1.0
@export var hit_flash_decay := 2.0
@export var hit_aberration := 0.008

@export_group("Stride")
@export var step_length := 0.6
@export var walk_bob := Vector3(0.014, 0.006, 0.1)
@export var run_bob := Vector3(0.032, 0.012, 0.25)
@export var thud_ratio := 0.25
@export_range(0.0, 3.0) var crouch_bob_scale := 2.0
@export_range(0.0, 1.0) var ads_bob_scale := 0.3

@export_group("Body")
@export var crouch_drop := 0.18
@export var crouch_speed := 14.0
@export var lean_degrees := 0.8
@export var lean_accel := 3.0
@export var sprint_lean_degrees := 0.5
@export var sprint_fov := 0.05

@export_group("Breathing")
@export var breath_rest := Vector2(0.024, 0.25)
@export var breath_winded := Vector2(0.05, 1.0)
@export var breath_roll_degrees := Vector2(0.06, 0.35)
@export var breath_fov := Vector2(0.002, 0.012)
@export_range(0.0, 1.0) var breath_moving_scale := 0.3
@export_range(0.0, 1.0) var breath_ads_scale := 0.5

@export_group("Winded")
@export_range(0.1, 1.0) var tired_below := 0.5
@export var winded_sag := 0.03
@export var winded_bob_boost := 0.6
@export var winded_vignette := 0.45
@export var winded_desaturate := 0.18
@export var winded_haze := 1.0
@export var winded_aberration := 0.004
@export var gasp_dip := 0.04
@export var gasp_decay := 1.2

@export_group("Near miss")
@export var miss_radius := 1.8
@export var miss_dip := 0.12
@export var miss_roll_degrees := 1.0
@export var miss_punch := 0.035
@export var miss_shake := 0.2
@export var miss_cooldown := 0.12
@export var miss_aberration := 0.005
@export var suppress_gain := 0.4
@export var suppress_decay := 0.7
@export var suppress_vignette := 0.28
@export var suppress_desaturate := 0.15
@export var suppress_haze := 0.8

@export_group("Gunfire")
@export var rumble_range := 14.0
@export_range(0.0, 2.0) var rumble_shake := 1.0
@export_range(0.0, 1.0) var rumble_kick := 0.5

@export_group("Reload")
@export var reload_dip := 0.03
@export var reload_roll_degrees := 0.12

@export_group("Air")
@export var jump_lift := 0.015
@export var jump_punch := 0.008
@export var land_min_speed := 1.0
@export var land_full_speed := 9.0
@export_range(0.2, 1.0) var land_curve := 0.55
@export var land_dip := 0.38
@export var land_punch := 0.05
@export var land_roll_degrees := 0.8
@export var land_shake := 0.5
@export var land_vignette := 0.1
@export var land_aberration := 0.007
@export var land_slam_decay := 3.5
@export var fall_lead_time := 0.1
@export var fall_lead_max := 0.8
@export var fall_lead_rates := Vector2(5.0, 10.0)
@export var fall_fov := 0.03

@export_group("Aim")
@export var ads_punch := 0.05
@export var ads_vignette := 0.5
@export var ads_aberration := 0.0035
@export var ads_snap := 0.15
@export var ads_snap_decay := 4.0

@export_group("Slow motion")
@export var slow_zoom := 0.05
@export var slow_vignette := 0.2
@export var slow_desaturate := 0.3
@export var slow_aberration := 0.003
@export var slow_focus := 0.5

@export_group("Hurt")
@export_range(0.1, 1.0) var hurt_below := 0.45
@export var hurt_vignette := 0.25
@export var hurt_desaturate := 0.3
@export var heartbeat_rest := 1.1
@export var heartbeat_hurt := 2.0

@export_group("Bleeding")
@export var bleed_full := 2.5
@export var bleed_vignette := 0.06
@export var bleed_desaturate := 0.04
@export var bleed_tick_hp := 1.0
@export var bleed_min_interval := 0.6
@export var bleed_dip := 0.012
@export var bleed_roll_degrees := 0.12
@export var bleed_pulse := 0.2
@export var bleed_pulse_decay := 3.0

@export_group("Death")
@export var death_zoom := 0.78
@export var death_time := 2.4
@export var death_roll_degrees := 2.5
@export var death_kick := 0.35
@export var death_shake := 0.7
@export var death_vignette := 0.55
@export var death_desaturate := 0.85
@export var death_focus := 0.8
@export var death_fade_time := 0.8
@export var intro_time := 0.7

const RELOAD_WEIGHT := {
	WeaponReload.Cue.RELEASE: 0.4,
	WeaponReload.Cue.PULL: 0.8,
	WeaponReload.Cue.STOW: 0.3,
	WeaponReload.Cue.GRAB: 0.5,
	WeaponReload.Cue.SEAT: 1.6,
	WeaponReload.Cue.DROP: 0.8,
	WeaponReload.Cue.UNLOCK: 1.0,
	WeaponReload.Cue.TAKE_SLIDE: 0.6,
	WeaponReload.Cue.LET_GO: 1.0,
}

var offset := Vector2.ZERO
var roll := 0.0
var fov_scale := 1.0

var _screen: ScreenFx
var _health: Health
var _stamina: PlayerStamina
var _slow_motion: PlayerSlowMotion
var _healing: PlayerHealing
var _carrier: WeaponCarrier
var _death: PlayerDeath
var _weapon: Weapon

var _noise := FastNoiseLite.new()
var _shake_x := Follow.new()
var _shake_y := Follow.new()
var _shake_roll := Follow.new()
var _clock := 0.0
var _trauma := 0.0
var _shown_trauma := 0.0

var _kick_x := WeaponRecoil.Spring.new()
var _kick_y := WeaponRecoil.Spring.new()
var _roll := WeaponRecoil.Spring.new()
var _punch := WeaponRecoil.Spring.new()
var _land := WeaponRecoil.Spring.new()
var _thud := WeaponRecoil.Spring.new()

var _soft_x := Follow.new()
var _soft_y := Follow.new()
var _soft_roll := Follow.new()
var _soft_zoom := Follow.new()

var _stride := 0.0
var _moving := Follow.new()
var _crouch := Follow.new()
var _sprint := Follow.new()
var _lean := Follow.new()
var _prev_vx := 0.0

var _tired := 0.0
var _was_exhausted := false
var _gasp := 0.0
var _breath := 0.0
var _beat := 0.0

var _fall := 0.0
var _fall_amount := Follow.new()
var _lead := Follow.new()
var _was_grounded := true

var _hit := 0.0
var _slam := 0.0
var _snap := 0.0
var _bleed := 0.0
var _bleed_hp := 0.0
var _ooze := 0.0
var _intro := 1.0
var _whiz := 0.0
var _whiz_side := 1.0
var _whiz_cool := 0.0
var _suppress := 0.0
var _crack := 0.0
var _dead := false
var _dead_time := 0.0
var _dead_side := 1.0

var _watched := { }
var _watch_left := 0.0


func _init() -> void:
	process_physics_priority = -10


func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0

	_kick_x.setup(TAU * kick_hz, kick_damping)
	_kick_y.setup(TAU * kick_hz, kick_damping)
	_roll.setup(TAU * 3.5, 0.85)
	_punch.setup(TAU * 4.0, 0.85)
	_land.setup(TAU * 2.6, 0.6)
	_thud.setup(TAU * 6.0, 0.85)

	_health = target.health
	_stamina = target.get_node("PlayerStamina") as PlayerStamina
	_slow_motion = target.get_node("PlayerSlowMotion") as PlayerSlowMotion
	_healing = target.get_node("PlayerHealing") as PlayerHealing
	_carrier = target.get_node("WeaponCarrier") as WeaponCarrier
	_death = target.get_node("PlayerDeath") as PlayerDeath

	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	target.jumped.connect(_on_jumped)

	_screen = ScreenFx.new()
	_screen.name = &"ScreenFx"
	add_child(_screen)



func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func _physics_process(delta: float) -> void:
	_watch_left -= delta
	if _watch_left <= 0.0:
		_watch_left = 0.5
		_watch_enemies()

	if _carrier.weapon != _weapon:
		_weapon = _carrier.weapon
		_weapon.fired.connect(_on_fired)
		_weapon.aim_changed.connect(_on_aim_changed)
		_weapon.reloader.cued.connect(_on_reload_cue)

	var speed := absf(target.velocity.x)
	var grounded := target.grounded
	var aim := target.aim_amount

	_kick_x.step(delta)
	_kick_y.step(delta)
	_roll.step(delta)
	_punch.step(delta)
	_land.step(delta)
	_thud.step(delta)

	var real := delta / maxf(Engine.time_scale, 0.05)

	_trauma = maxf(_trauma - trauma_decay * delta, 0.0)
	_shown_trauma = lerpf(_shown_trauma, _trauma, 1.0 - exp(-shake_attack * delta))
	_hit = maxf(_hit - hit_flash_decay * delta, 0.0)
	_slam = maxf(_slam - land_slam_decay * delta, 0.0)
	_snap = maxf(_snap - ads_snap_decay * delta, 0.0)
	_whiz_cool = maxf(_whiz_cool - delta, 0.0)
	_suppress = maxf(_suppress - suppress_decay * delta, 0.0)
	_crack = maxf(_crack - 7.0 * delta, 0.0)
	if _whiz > 0.0:
		_flinch(_whiz)
		_whiz = 0.0
	_clock += shake_hz * delta

	var power := _shown_trauma * _shown_trauma
	var shake_omega := TAU * shake_smoothing_hz
	var shake := Vector3(
		_shake_x.step(_noise.get_noise_2d(_clock, 0.0) * power if power > 0.0 else 0.0, shake_omega, delta),
		_shake_y.step(_noise.get_noise_2d(_clock, 31.7) * power if power > 0.0 else 0.0, shake_omega, delta),
		_shake_roll.step(_noise.get_noise_2d(_clock, 63.1) * power if power > 0.0 else 0.0, shake_omega, delta),
	)

	var run := smoothstep(target.walk_speed, target.run_speed, speed)
	var walking := smoothstep(0.1, target.walk_speed, speed) if grounded else 0.0
	var moving := _moving.step(walking, 9.0, delta)
	var crouch := _crouch.step(1.0 if target.crouching else 0.0, crouch_speed, delta)
	var sprint := _sprint.step(run * (1.0 - aim), 9.0, delta)

	var bob := walk_bob.lerp(run_bob, run) * moving
	bob *= lerpf(1.0, crouch_bob_scale, crouch) * lerpf(1.0, ads_bob_scale, aim) * (1.0 + winded_bob_boost * _tired)

	if grounded:
		var before := floori(_stride)
		_stride += speed / step_length * delta
		if floori(_stride) != before:
			_thud.kick(-bob.x * thud_ratio)

	var step := TAU * _stride
	var bob_y := -bob.x * cos(step)
	var bob_x := bob.y * sin(step * 0.5)
	var bob_roll := bob.z * sin(step * 0.5)

	var accel := (target.velocity.x - _prev_vx) / delta
	_prev_vx = target.velocity.x
	var banking := _lean.step(clampf(accel / lean_accel, -1.0, 1.0), 12.0, delta)

	var drained := smoothstep(tired_below, 0.0, _stamina.fraction())
	_tired = lerpf(_tired, maxf(drained, 0.85 if _stamina.exhausted else 0.0), 1.0 - exp(-2.5 * delta))
	if _stamina.exhausted != _was_exhausted:
		_was_exhausted = _stamina.exhausted
		if _was_exhausted:
			_gasp = 1.0
			_land.kick(-gasp_dip)
			add_trauma(0.1)
		else:
			_punch.kick(-ads_punch * 0.4)

	_gasp = maxf(_gasp - gasp_decay * delta, 0.0)

	var breath := breath_rest.lerp(breath_winded, _tired)
	_breath += breath.y * delta

	var calm := lerpf(1.0, breath_moving_scale, moving * (1.0 - _tired)) * lerpf(1.0, breath_ads_scale, aim * (1.0 - _tired))
	var inhale := sin(TAU * _breath - 0.5 * sin(TAU * _breath))
	var gulp := 0.5 + 0.5 * inhale
	var breath_y := breath.x * calm * inhale
	var breath_x := breath.x * calm * 0.35 * sin(PI * _breath + 1.3)

	_update_air(delta, grounded)

	var slow := 0.0 if _dead else _slow_motion.amount
	var hurt := 0.0 if _dead else 1.0 - smoothstep(0.0, hurt_below, _health.current / _health.max_health)
	_bleed = lerpf(_bleed, 0.0 if _dead else clampf(_healing.bleed_rate() / bleed_full, 0.0, 1.0), 1.0 - exp(-2.0 * delta))
	_tick_bleeding(delta)
	_beat += lerpf(heartbeat_rest, heartbeat_hurt, hurt) * delta
	var beat := pow(maxf(sin(TAU * _beat), 0.0), 8.0)
	var pulse := beat * hurt

	var death := 0.0
	if _dead:
		_dead_time += real
		death = 1.0 - pow(1.0 - clampf(_dead_time / death_time, 0.0, 1.0), 3.0)

	var omega := TAU * smoothing_hz
	var kick := _soft_limit(Vector2(_kick_x.x, _kick_y.x), kick_limit)
	var jolt := Vector2(
		_soft_x.step(kick.x, omega, delta),
		_soft_y.step(kick.y + _thud.x + _land.x, omega, delta),
	)
	var jolt_roll := _soft_roll.step(_roll.x, omega, delta)
	var jolt_zoom := _soft_zoom.step(_punch.x, omega * 0.75, delta)

	offset = Vector2(
		shake.x * shake_move.x + jolt.x + bob_x + breath_x,
		shake.y * shake_move.y + jolt.y + bob_y + breath_y - crouch_drop * crouch - winded_sag * _tired + _lead.x,
	) * intensity

	var lean := -banking * lean_degrees - signf(target.velocity.x) * sprint * sprint_lean_degrees
	var tilt := shake.z * shake_roll_degrees + bob_roll + lean + lerpf(breath_roll_degrees.x, breath_roll_degrees.y, _tired) * calm * inhale
	roll = intensity * (jolt_roll + deg_to_rad(tilt + _dead_side * death_roll_degrees * death))

	var zoom := jolt_zoom + sprint_fov * sprint + fall_fov * _fall_amount.x - slow_zoom * slow
	zoom += lerpf(breath_fov.x, breath_fov.y, _tired) * calm * inhale
	fov_scale = (1.0 + zoom * intensity) * lerpf(1.0, death_zoom, death)

	var scope := clampf((target.aim_look - 1.0) / 3.5, 0.0, 1.0)
	_screen.vignette = (
		land_vignette * _slam * _slam
		+ bleed_vignette * _bleed
		+ bleed_pulse * _ooze
		+ winded_vignette * _tired * (0.55 + 0.45 * gulp)
		+ 0.2 * _gasp
		+ suppress_vignette * _suppress
		+ slow_vignette * slow
		+ hurt_vignette * hurt * (1.0 + 0.8 * pulse)
		+ 0.06 * _hit
		+ death_vignette * death
	)
	_screen.aberration = hit_aberration * _hit + slow_aberration * slow + 0.004 * power + 0.004 * pulse
	_screen.aberration += land_aberration * _slam * _slam + ads_aberration * _snap
	_screen.aberration += winded_aberration * _tired * gulp + 0.004 * _gasp + 0.002 * _ooze + miss_aberration * _crack
	_screen.haze = winded_haze * _tired * (0.6 + 0.4 * gulp) + suppress_haze * _suppress
	_screen.focus = maxf(aim * lerpf(0.6, 1.0, scope), maxf(slow_focus * slow, death_focus * death))
	_screen.scope = (ads_vignette * aim + ads_snap * _snap) * lerpf(0.7, 1.3, scope)
	_screen.scope_dir = _aim_direction(aim)
	_screen.desaturate = slow_desaturate * slow + hurt_desaturate * hurt + bleed_desaturate * _bleed + winded_desaturate * _tired + suppress_desaturate * _suppress + death_desaturate * death
	_screen.blood = clampf(0.6 * _hit + 0.5 * hurt + 0.25 * _bleed + 0.9 * _ooze + 0.6 * death, 0.0, 1.0)
	_intro = maxf(_intro - real / intro_time, 0.0)
	_screen.fade = smoothstep(0.0, 1.0, _intro)
	if _dead and _death.restart_delay > 0.0:
		_screen.fade = maxf(_screen.fade, 1.0 - clampf((_death.restart_delay - _dead_time) / death_fade_time, 0.0, 1.0))


func _update_air(delta: float, grounded: bool) -> void:
	var vy := target.velocity.y

	if grounded:
		if not _was_grounded:
			var impact := pow(
				clampf((-_fall - land_min_speed) / (land_full_speed - land_min_speed), 0.0, 1.0),
				land_curve,
			)
			if impact > 0.0:
				_land.kick(-land_dip * impact)
				_punch.kick(-land_punch * impact)
				_roll.kick(deg_to_rad(land_roll_degrees) * impact * (1.0 if randf() < 0.5 else -1.0))
				add_trauma(land_shake * impact)
				_slam = maxf(_slam, impact)

		_fall = 0.0
	else:
		_fall = minf(_fall, vy)

	_was_grounded = grounded

	var lead := 0.0 if grounded else clampf(vy * fall_lead_time, -fall_lead_max, 0.0)
	_lead.step(lead, fall_lead_rates.x if lead < _lead.x else fall_lead_rates.y, delta)

	var falling := 0.0 if grounded else smoothstep(land_min_speed, land_full_speed, -vy)
	_fall_amount.step(falling, 7.5, delta)


func _tick_bleeding(delta: float) -> void:
	_ooze = maxf(_ooze - bleed_pulse_decay * delta, 0.0)

	var rate := 0.0 if _dead else _healing.bleed_rate()
	if rate <= 0.0:
		_bleed_hp = 0.0
		return

	_bleed_hp += rate * delta
	if _bleed_hp < maxf(bleed_tick_hp, rate * bleed_min_interval):
		return

	_bleed_hp = 0.0
	_ooze = clampf(0.45 + 0.12 * rate, 0.45, 0.85)
	_land.kick(-bleed_dip * _ooze)
	_roll.kick(deg_to_rad(bleed_roll_degrees) * _ooze * (1.0 if randf() < 0.5 else -1.0))


func _aim_direction(aim: float) -> Vector2:
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d()
	var from := camera.unproject_position(target.global_position + Vector3.UP * target.aim_origin_height)
	_screen.scope_anchor = from / viewport.get_visible_rect().size

	if aim < 0.01:
		return _screen.scope_dir

	var to := camera.unproject_position(target.aim_point)
	return Vector2(to.x - from.x, from.y - to.y).normalized()


func _soft_limit(v: Vector2, cap: float) -> Vector2:
	var length := v.length()
	if length < 0.0001:
		return v

	return v * (cap * tanh(length / cap) / length)


func _on_fired(muzzle: Transform3D) -> void:
	var stats := _weapon.stats
	var strength := lerpf(1.0, stats.ads_recoil_scale, target.aim_amount)
	strength *= 1.0 + kick_variation * randf_range(-1.0, 1.0)

	var distance := stats.camera_kick * strength
	var back := -Vector2(muzzle.basis.x.x, muzzle.basis.x.y).normalized()
	var push := back.rotated(kick_variation * randf_range(-1.0, 1.0)) * distance
	push.y += distance * kick_lift

	_kick_x.kick(push.x)
	_kick_y.kick(push.y)
	_roll.kick(deg_to_rad(kick_roll_degrees_per_meter * distance) * float(target.facing))
	_punch.kick(-kick_punch_per_meter * distance)
	add_trauma(stats.camera_shake * strength)


func _watch_enemies() -> void:
	for gone in _watched.keys():
		if not is_instance_valid(gone):
			_watched.erase(gone)

	for node in get_tree().get_nodes_in_group(&"enemies"):
		var weapon := (node as EnemyInput).carrier.weapon
		if not is_instance_valid(weapon) or _watched.has(weapon):
			continue

		_watched[weapon] = true
		weapon.fired.connect(_on_enemy_fired.bind(weapon))
		weapon.bullet_traced.connect(_on_enemy_bullet.bind(weapon))


func _chest() -> Vector2:
	return Vector2(target.global_position.x, target.global_position.y + 1.0)


func _on_enemy_fired(muzzle: Transform3D, weapon: Weapon) -> void:
	var away := _chest() - Vector2(muzzle.origin.x, muzzle.origin.y)
	var near := 1.0 - smoothstep(1.0, rumble_range, away.length())
	if near <= 0.0 or _dead:
		return

	var stats := weapon.stats
	var push := away.normalized() * stats.camera_kick * rumble_kick * near
	_kick_x.kick(push.x)
	_kick_y.kick(push.y)
	add_trauma(stats.camera_shake * rumble_shake * near)


func _on_enemy_bullet(from: Vector3, to: Vector3, hit: Dictionary, weapon: Weapon) -> void:
	if _dead or (not hit.is_empty() and Health.of(hit.collider) == _health):
		return

	var start := Vector2(from.x, from.y)
	var path := Vector2(to.x, to.y) - start
	var length_squared := path.length_squared()
	if length_squared < 0.0001:
		return

	var me := _chest()
	var along := (me - start).dot(path) / length_squared
	if along < 0.0:
		return

	var gap := me.distance_to(start + path * minf(along, 1.0))
	var close := 1.0 - smoothstep(0.3, miss_radius, gap)
	if close <= 0.0:
		return

	_whiz = maxf(_whiz, close * clampf(weapon.stats.damage / 25.0, 0.7, 1.8))
	_whiz_side = signf(path.cross(me - start))


func _flinch(strength: float) -> void:
	_suppress = minf(_suppress + suppress_gain * strength, 1.0)
	_crack = maxf(_crack, minf(strength, 1.0))
	if _whiz_cool > 0.0:
		return

	_whiz_cool = miss_cooldown
	var s := minf(strength, 1.5)
	_thud.kick(-miss_dip * s)
	_roll.kick(deg_to_rad(miss_roll_degrees) * s * _whiz_side)
	_punch.kick(-miss_punch * s)
	add_trauma(miss_shake * s)


func _on_reload_cue(cue: WeaponReload.Cue) -> void:
	var weight: float = RELOAD_WEIGHT.get(cue, 0.0)
	if weight == 0.0:
		return

	_thud.kick(-reload_dip * weight)
	_roll.kick(deg_to_rad(reload_roll_degrees) * weight * float(target.facing))
	if cue == WeaponReload.Cue.SEAT:
		_punch.kick(-0.004)
		add_trauma(0.03)


func _on_aim_changed(aiming: bool) -> void:
	_punch.kick(ads_punch if aiming else -ads_punch * 0.6)
	if aiming:
		_snap = 1.0


func _on_damaged(amount: float, point: Vector3, direction: Vector3, _bone: PhysicalBone3D) -> void:
	var weight := clampf(amount / 25.0, 0.4, 2.5)
	var travel := Vector2(direction.x, direction.y).normalized()
	var push := travel * hit_kick * weight

	_kick_x.kick(push.x)
	_kick_y.kick(push.y)
	_roll.kick(deg_to_rad(hit_roll_degrees) * weight * signf(direction.x))
	_punch.kick(-hit_punch * weight)
	add_trauma(hit_shake * weight)
	_hit = minf(_hit + 0.4 * weight, 1.0)

	if travel != Vector2.ZERO:
		_streak(point, travel, clampf(amount / 30.0, 0.6, 1.0))


func _streak(point: Vector3, travel: Vector2, strength: float) -> void:
	var viewport := get_viewport()
	var size := viewport.get_visible_rect().size
	var from := (viewport.get_camera_3d().unproject_position(point) / size).clamp(Vector2.ZERO, Vector2.ONE)

	var inward := Vector2(travel.x, -travel.y)
	var back := from * size
	var reach := INF
	if inward.x != 0.0:
		reach = minf(reach, (back.x if inward.x > 0.0 else size.x - back.x) / absf(inward.x))

	if inward.y != 0.0:
		reach = minf(reach, (back.y if inward.y > 0.0 else size.y - back.y) / absf(inward.y))

	_screen.add_hit((back - inward * reach) / size, inward, strength)


func _on_died() -> void:
	var direction := Vector2(_health.last_direction.x, _health.last_direction.y).normalized()
	_dead = true
	_dead_side = signf(direction.x) if direction.x != 0.0 else 1.0

	_kick_x.kick(direction.x * death_kick)
	_kick_y.kick(direction.y * death_kick)
	add_trauma(death_shake)
	_hit = 1.0


func _on_jumped() -> void:
	_land.kick(jump_lift)
	_punch.kick(jump_punch)
