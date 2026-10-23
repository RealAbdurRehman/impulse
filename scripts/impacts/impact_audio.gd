class_name ImpactAudio
extends Node

const BUS := &"Weapons"

@export var voices := 12
@export var min_gap := 0.03
@export var unit_size := 30.0
@export var max_distance := 90.0

var _pool: Array[AudioStreamPlayer3D] = []
var _next := 0
var _last := -100.0


func _ready() -> void:
	for i in voices:
		var voice := AudioStreamPlayer3D.new()
		voice.bus = BUS
		voice.unit_size = unit_size
		voice.max_distance = max_distance
		add_child(voice)
		_pool.append(voice)


func play(sound: SoundSet, at: Vector3, extra_db: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	if now - _last < min_gap:
		return

	_last = now

	var voice := _pool[_next]
	_next = (_next + 1) % _pool.size()

	var source := sound.pick()
	var v := sound.pitch_variation
	var db := sound.volume_variation_db

	voice.stream = source
	voice.global_position = at
	voice.pitch_scale = 1.0 + randf_range(-v, v)
	voice.volume_db = sound.volume_db + sound.gain_db + extra_db + randf_range(-db, db)
	voice.play(sound.skip)
