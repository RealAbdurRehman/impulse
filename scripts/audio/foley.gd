class_name Foley
extends Node

class Voice extends AudioStreamPlayer3D:
	var strength := -100.0

const BUS := &"Foley"
const VOICES := 32
const MAX_RANGE := 45.0
const FLOOR_DB := -34.0
const STEP_PAN := 0.5
const NPC_STEP_GAP := 0.08
const NPC_STEP_RANGE := 26.0
const NPC_STEP_NEAR := 4.0
const NPC_STEP_FALLOFF := 1.1
const TIERS := {
	&"concrete": [Vector2i(5, 10), Vector2i(5, 10), Vector2i(5, 10), Vector2i(0, 5)],
	&"metal": [Vector2i(0, 5), Vector2i(5, 10), Vector2i(10, 15), Vector2i(15, 20)],
	&"wood": [Vector2i(0, 5), Vector2i(5, 10), Vector2i(10, 15), Vector2i(15, 20)],
	&"glass": [Vector2i(0, 5), Vector2i(5, 10), Vector2i(10, 15), Vector2i(10, 15)],
	&"plastic": [Vector2i(5, 10), Vector2i(10, 15), Vector2i(0, 5), Vector2i(0, 5)],
	&"flesh": [Vector2i(0, 5), Vector2i(5, 10), Vector2i(10, 15), Vector2i(10, 15)],
}
const FOLDERS := {
	&"concrete": "impacts/concrete",
	&"metal": "impacts/metal",
	&"wood": "impacts/wood",
	&"glass": "impacts/glass",
	&"plastic": "impacts/plastic",
	&"flesh": "impacts/body",
}
const BIAS := {
	&"concrete": 0.0,
	&"metal": -2.0,
	&"wood": 0.0,
	&"glass": -4.0,
	&"plastic": 1.0,
	&"flesh": 0.0,
}
const STEPS := {
	&"concrete": "footsteps/concrete",
	&"metal": "footsteps/metal",
	&"wood": "footsteps/wood",
	&"plastic": "footsteps/concrete",
	&"glass": "footsteps/concrete",
}
const STEP_SETS := {
	&"concrete": Vector2i(5, 14),
	&"metal": Vector2i(0, 8),
	&"wood": Vector2i(0, 5),
	&"plastic": Vector2i(5, 14),
	&"glass": Vector2i(5, 14),
}
const STEP_TUNE := {
	&"concrete": Vector2(1.0, 0.0),
	&"metal": Vector2(1.0, -1.0),
	&"wood": Vector2(1.0, 0.0),
	&"plastic": Vector2(1.1, -2.0),
	&"glass": Vector2(1.15, -4.0),
}

static var _current: Foley

@export var unit_size := 20.0
@export var max_distance := 90.0
@export_range(0.0, 1.0) var panning := 0.8

var _voices: Array[Voice] = []
var _last := { }


static func of(node: Node) -> Foley:
	if not is_instance_valid(_current) or not _current.is_inside_tree():
		_current = Foley.new()
		_current.name = &"Foley"
		node.get_tree().current_scene.add_child(_current)

	return _current


func _ready() -> void:
	for i in VOICES:
		var voice := Voice.new()
		voice.bus = BUS
		voice.unit_size = unit_size
		voice.max_distance = max_distance
		voice.panning_strength = panning
		voice.attenuation_filter_cutoff_hz = 12000.0
		voice.attenuation_filter_db = -12.0
		add_child(voice)
		_voices.append(voice)


func step(at: Vector3, surface: StringName, loud: float, extra_db := 0.0, npc := false) -> void:
	var fade := 0.0
	if npc:
		var gap := _gap(at)
		if gap > NPC_STEP_RANGE or not _ready_for("npc_step", NPC_STEP_GAP):
			return

		fade = maxf(gap - NPC_STEP_NEAR, 0.0) * NPC_STEP_FALLOFF

	var tune: Vector2 = STEP_TUNE[surface]
	var span: Vector2i = STEP_SETS[surface]
	var bank := SoundBank.of(STEPS[surface])
	var stream := bank.pick(span.x, span.y)
	var db := lerpf(-17.0, -2.0, pow(loud, 0.8)) + tune.y + bank.gain_db + extra_db - fade
	var rate := tune.x * lerpf(1.04, 0.96, loud) * randf_range(0.97, 1.03)
	_play(stream, at, db, rate, STEP_PAN)


func hit(at: Vector3, surface: StringName, intensity: float, extra_db := 0.0, pitch := 1.0, tier := -1) -> void:
	if not _ready_for("hit_" + surface, 0.03):
		return

	var level := clampf(intensity, 0.0, 1.0)
	var bank := SoundBank.of(FOLDERS[surface])
	var tiers: Array = TIERS[surface]
	var span: Vector2i = tiers[_tier(level) if tier < 0 else tier]
	var stream := bank.pick(span.x, span.y)
	var base: float = lerpf(-24.0, -1.0, pow(level, 0.65)) + BIAS[surface] + extra_db
	var rate := pitch * lerpf(1.12, 0.9, level) * randf_range(0.96, 1.04)
	_play(stream, at, base + bank.gain_db, rate)
	if level > 0.8 and tier < 0:
		var boom: Vector2i = tiers[3]
		var low := bank.pick(boom.x, boom.y)
		_play(low, at, base - 7.0 + bank.gain_db, rate * 0.9)


func thud(at: Vector3, intensity: float, extra_db := 0.0) -> void:
	if not _ready_for("thud", 0.04):
		return

	var level := clampf(intensity, 0.0, 1.0)
	var bank := SoundBank.of("impacts/body")
	var span := Vector2i(0, 5)
	if randf() < level - 0.45:
		span = Vector2i(5, 10) if level < 0.8 else Vector2i(10, 15)

	var stream := bank.pick(span.x, span.y)
	var db := lerpf(-16.0, 4.0, pow(level, 0.6)) + bank.gain_db + extra_db
	_play(stream, at, db, lerpf(1.1, 0.88, level) * randf_range(0.96, 1.04))


func bullet(at: Vector3, surface: StringName, size: float, exiting: bool) -> void:
	if not _ready_for("bullet_" + surface, 0.03):
		return

	var level := clampf(size * 0.45, 0.2, 0.75)
	var db := -8.0 if exiting else -2.0
	if surface == &"flesh":
		thud(at, level + 0.2, db + 3.0)
	else:
		hit(at, surface, level, db - 2.0, 1.1)


func _gap(at: Vector3) -> float:
	var camera := get_viewport().get_camera_3d()
	return absf(at.x - camera.global_position.x) if camera != null else 0.0


func _tier(level: float) -> int:
	var mixed := level + randf_range(-0.08, 0.08)
	return 0 if mixed < 0.33 else 1 if mixed < 0.66 else 2


func _ready_for(key: String, gap: float) -> bool:
	var now := Time.get_ticks_msec() * 0.001
	if now - _last.get(key, -10.0) < gap:
		return false

	_last[key] = now
	return true


func _play(stream: AudioStream, at: Vector3, db: float, rate: float, pan := panning) -> void:
	if db < FLOOR_DB:
		return

	var camera := get_viewport().get_camera_3d()
	if camera != null and absf(at.x - camera.global_position.x) > MAX_RANGE:
		return

	var voice := _acquire(db)
	if voice == null:
		return

	voice.stream = stream
	voice.global_position = at
	voice.volume_db = db
	voice.pitch_scale = rate
	voice.panning_strength = pan
	voice.strength = db
	voice.play()


func _acquire(db: float) -> Voice:
	var weakest := _voices[0]
	for voice in _voices:
		if not voice.playing:
			return voice

		if voice.strength < weakest.strength:
			weakest = voice

	return weakest if weakest.strength < db else null
