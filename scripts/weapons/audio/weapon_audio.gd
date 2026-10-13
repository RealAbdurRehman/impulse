class_name WeaponAudio
extends Node


class Voice extends AudioStreamPlayer:
	var fade: Tween


	func start(source: AudioStream, pitch: float, db: float, from: float) -> void:
		if fade != null:
			fade.kill()

		stream = source
		pitch_scale = pitch
		volume_db = db
		play(from)


	func fade_out(time: float) -> void:
		if not playing:
			return

		fade = create_tween()
		fade.tween_property(self, "volume_db", -60.0, time)
		fade.tween_callback(stop)


const BUS := &"Weapons"
const BODY_BUS := &"WeaponBody"

@export var voices := 24

var weapon: Weapon

var _sounds: WeaponSounds
var _pool: Array[Voice] = []
var _next := 0
var _shot: Array[Voice] = []
var _burst := 0
var _last_shot := -100.0
var _last_aim := -100.0
var _last_casing := -100.0


func _ready() -> void:
	weapon = get_parent() as Weapon
	_sounds = weapon.stats.sounds

	for i in voices:
		var voice := Voice.new()
		add_child(voice)
		_pool.append(voice)

	weapon.fired.connect(_on_fired)
	weapon.dry_fired.connect(_handle.bind(_sounds.dry_fire))
	weapon.animator.slide_locked.connect(_handle.bind(_sounds.slide_lock))
	weapon.animator.selector_clicked.connect(_handle.bind(_sounds.fire_mode))
	weapon.reloader.cued.connect(_on_cue)
	weapon.aim_changed.connect(_on_aim)


func casing_landed(speed: float) -> void:
	var now := _now()
	if speed < _sounds.casing_min_speed or now - _last_casing < _sounds.casing_gap:
		return

	_last_casing = now

	var loud := clampf(speed / _sounds.casing_full_speed, 0.05, 1.0)
	_play(_sounds.casing, linear_to_db(loud) * _sounds.casing_falloff)


func _on_aim(aiming: bool) -> void:
	var now := _now()
	if now - _last_aim < _sounds.aim_gap:
		return

	_last_aim = now

	if aiming:
		_handle(_sounds.aim_in)
	else:
		_handle(_sounds.aim_out, _sounds.aim_out_db, _sounds.aim_out_pitch)


func _on_fired(_muzzle: Transform3D) -> void:
	var now := _now()
	if now - _last_shot > _sounds.burst_reset:
		_burst = 0

	_last_shot = now

	for voice in _shot:
		voice.fade_out(_sounds.tail_fade)

	_shot.clear()

	var drop := -minf(float(_burst) * _sounds.burst_drop_db, _sounds.burst_max_drop_db)
	_burst += 1

	_shot.append(_play(_sounds.fire, drop, _sounds.fire_pitch))
	_shot.append(
		_play(
			_sounds.fire,
			drop + _sounds.body_db,
			_sounds.body_pitch * _sounds.fire_pitch,
			BODY_BUS,
		),
	)


func _on_cue(cue: WeaponReload.Cue) -> void:
	match cue:
		WeaponReload.Cue.PULL, WeaponReload.Cue.DROP:
			_handle(_sounds.mag_out)

		WeaponReload.Cue.SEAT:
			_handle(_sounds.mag_in, _sounds.tactical_db if weapon.ammo > 0 else 0.0)

		WeaponReload.Cue.UNLOCK:
			if _sounds.slide_release:
				_handle(_sounds.slide_release)

		WeaponReload.Cue.TAKE_SLIDE:
			_handle(_sounds.rack_back)

		WeaponReload.Cue.LET_GO:
			_handle(_sounds.rack_forward)


func _handle(sound: SoundSet, extra_db := 0.0, pitch := 1.0) -> void:
	if _now() - _last_shot < _sounds.duck_time:
		extra_db += _sounds.duck_db

	_play(sound, extra_db, pitch)


func _play(sound: SoundSet, extra_db := 0.0, pitch := 1.0, bus := BUS) -> Voice:
	var voice := _pool[_next]
	_next = (_next + 1) % _pool.size()

	var v := sound.pitch_variation
	var db := sound.volume_variation_db

	var source := sound.pick()

	voice.bus = bus
	voice.start(
		source,
		pitch * (1.0 + randf_range(-v, v)),
		sound.volume_db + sound.gain_db + extra_db + randf_range(-db, db),
		sound.skip,
	)

	return voice


func _now() -> float:
	return Time.get_ticks_msec() * 0.001
