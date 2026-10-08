class_name WeaponRecoil
extends Node


class Spring:
	var x := 0.0
	var v := 0.0
	var omega := 30.0
	var zeta := 0.5
	var gain := 1.0


	func setup(angular_frequency: float, ratio: float) -> void:
		omega = angular_frequency
		zeta = clampf(ratio, 0.05, 0.98)

		var damped := omega * sqrt(1.0 - zeta * zeta)
		var decay := zeta * omega
		var peak_time := atan2(damped, decay) / damped
		gain = exp(-decay * peak_time) * sin(damped * peak_time) / damped


	func kick(peak: float) -> void:
		v += peak / gain


	func step(delta: float) -> void:
		var damped := omega * sqrt(1.0 - zeta * zeta)
		var decay := zeta * omega
		var fall := exp(-decay * delta)
		var c := cos(damped * delta)
		var s := sin(damped * delta)

		var next_x := fall * (x * c + (v + decay * x) / damped * s)
		var next_v := fall * (v * c - (decay * v + omega * omega * x) / damped * s)
		x = next_x
		v = next_v


	func resting() -> bool:
		return absf(x) < 0.00001 and absf(v) < 0.0001


@export_group("Dynamics")
@export var flip_frequency_hz := 4.5
@export_range(0.1, 0.95) var flip_damping := 0.62

@export var slide_frequency_hz := 5.4
@export_range(0.1, 0.95) var slide_damping := 0.6

@export var body_frequency_hz := 1.75
@export_range(0.1, 0.95) var body_damping := 0.5

@export var arm_lag := 0.033

var weapon: Weapon

var flip := 0.0
var slide := 0.0
var torso := 0.0
var hips_back := 0.0
var hips_drop := 0.0

var _flip := Spring.new()
var _slide := Spring.new()
var _body := Spring.new()

var _seen := 0.0
var _history := PackedFloat32Array()


func _ready() -> void:
	set_physics_process(false)

	weapon = get_parent() as Weapon
	if weapon == null:
		return

	_flip.setup(TAU * flip_frequency_hz, flip_damping)
	_slide.setup(TAU * slide_frequency_hz, slide_damping)
	_body.setup(TAU * body_frequency_hz, body_damping)

	weapon.fired.connect(_on_fired)
	_link()


func aim_correction() -> float:
	var facing := 1.0
	if weapon.player != null and "facing" in weapon.player:
		facing = float(weapon.player.facing)

	return -facing * _seen * (1.0 - weapon.stats.recoil_aim_influence)


func _link() -> void:
	var spine := weapon.holder.spine if weapon.holder != null else null
	if spine == null:
		return

	spine.recoil = self

	var skeleton := spine.get_parent()
	if skeleton == null:
		return

	for c in skeleton.get_children():
		if c is HipsModifier:
			c.recoil = self


func _on_fired(_muzzle: Transform3D) -> void:
	var s := weapon.stats
	var strength: int = 1.0 + s.recoil_variation * randf_range(-1.0, 1.0)

	_flip.kick(deg_to_rad(s.recoil_flip_degrees) * strength)
	_slide.kick(s.recoil_slide * strength)
	_body.kick(lerpf(1.0, strength, 0.5))

	var player := weapon.player
	if player != null and player.has_method(&"push_back") and "facing" in player:
		player.call(&"push_back", s.recoil_push * strength)

	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_flip.step(delta)
	_slide.step(delta)
	_body.step(delta)

	var s := weapon.stats
	var cap: int = s.recoil_stacking

	flip = _limit(_flip.x, deg_to_rad(s.recoil_flip_degrees) * cap)
	slide = _limit(_slide.x, s.recoil_slide * cap)

	var body := _limit(_body.x, cap)
	torso = body * deg_to_rad(s.recoil_torso_degrees)
	hips_back = body * s.recoil_hips_back
	hips_drop = body * s.recoil_hips_drop

	_history.append(flip)
	var lag := int(round(arm_lag * float(Engine.physics_ticks_per_second)))
	while _history.size() > lag + 1:
		_history.remove_at(0)

	_seen = _history[0]

	if _flip.resting() and _slide.resting() and _body.resting():
		set_physics_process(false)
		flip = 0.0
		slide = 0.0
		torso = 0.0
		hips_back = 0.0
		hips_drop = 0.0
		_seen = 0.0
		_history.clear()


func _limit(value: float, cap: float) -> float:
	if cap < 0.00001:
		return 0.0

	return cap * tanh(value / cap)
