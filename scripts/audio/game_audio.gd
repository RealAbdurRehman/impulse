class_name GameAudio
extends Node

enum Mode { NONE, MENU, LEVEL }

const HOVER := {"file": "ui_hover", "db": -12.0, "pitch": 0.85}
const PRESS := {"file": "ui_press", "db": -6.0, "pitch": 0.9}
const TOGGLE := {"file": "ui_toggle", "db": -6.0, "pitch": 0.85}
const SLIDE := {"file": "ui_slide", "db": -14.0, "pitch": 0.8}

static var _shared: GameAudio

@export var music_fade := 5.0
@export var ambience_fade := 6.0
@export var enter_time := 3.0
@export var leave_time := 1.5
@export var drift_depth_db := 1.5
@export var duck_db := -7.0
@export var duck_attack := 14.0
@export var duck_release := 1.6
@export var paused_db := -9.0
@export var sting_duck_db := -10.0
@export var sting_db := -8.0
@export var hover_gap := 0.04
@export var slide_gap := 0.05

var _mode := Mode.NONE
var _music: CrossfadePlayer
var _layers: Array[CrossfadePlayer] = []
var _phases: Array[float] = []
var _rates: Array[float] = []
var _ui: Array[AudioStreamPlayer] = []
var _next_ui := 0
var _sting: AudioStreamPlayer
var _duck := 0.0
var _bias := 0.0
var _pinned := 0.0
var _ambience_bus := 0
var _weapon_bus := 0
var _ambience_base := 0.0
var _last_nav := -10.0
var _last := { }
var _clock := 0.0


static func of(tree: SceneTree) -> GameAudio:
	if not is_instance_valid(_shared):
		_shared = GameAudio.new()
		_shared.name = &"GameAudio"
		tree.root.add_child.call_deferred(_shared)

	return _shared


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ambience_bus = AudioServer.get_bus_index(&"Ambience")
	_weapon_bus = AudioServer.get_bus_index(&"Weapons")
	_ambience_base = AudioServer.get_bus_volume_db(_ambience_bus)

	_music = _crossfader(&"Music", SoundBank.of("music"), music_fade)
	for track in ["ambient_01", "ambient_02"]:
		_layers.append(_crossfader(&"Ambience", SoundBank.of("ambience", track), ambience_fade))
		_phases.append(randf() * TAU)
		_rates.append(randf_range(0.02, 0.045))

	_sting = AudioStreamPlayer.new()
	_sting.bus = &"Music"
	add_child(_sting)
	for i in 4:
		var voice := AudioStreamPlayer.new()
		voice.bus = &"UI"
		add_child(voice)
		_ui.append(voice)

	for node in get_tree().root.find_children("*", "Control", true, false):
		_wire(node)

	get_tree().node_added.connect(_wire)
	_apply()


func _process(delta: float) -> void:
	_clock += delta
	for i in _layers.size():
		_layers[i].level_db = sin(_clock * _rates[i] * TAU + _phases[i]) * drift_depth_db

	var peak := AudioServer.get_bus_peak_volume_left_db(_weapon_bus, 0)
	var want := clampf(inverse_lerp(-30.0, -6.0, peak), 0.0, 1.0)
	_duck = lerpf(_duck, want, 1.0 - exp(-(duck_attack if want > _duck else duck_release) * delta))
	_pinned = maxf(_pinned - delta, 0.0)
	var target := (paused_db if get_tree().paused else 0.0) + (sting_duck_db if _pinned > 0.0 else 0.0)
	_bias = lerpf(_bias, target, 1.0 - exp(-4.0 * delta))
	AudioServer.set_bus_volume_db(_ambience_bus, _ambience_base + _duck * duck_db + _bias)


func play(mode: Mode) -> void:
	_mode = mode
	if is_node_ready():
		_apply()


func victory() -> void:
	var bank := SoundBank.of("ui", "victory")
	var stream := bank.pick()
	_sting.stream = stream
	_sting.volume_db = bank.gain_db + sting_db
	_sting.play()
	_pinned = stream.get_length()


func _apply() -> void:
	if _mode == Mode.MENU:
		_music.start(music_fade)
		for layer in _layers:
			layer.stop(leave_time)
	elif _mode == Mode.LEVEL:
		_music.stop(leave_time)
		for layer in _layers:
			layer.start(enter_time)


func _crossfader(bus: StringName, bank: SoundBank.Bank, time: float) -> CrossfadePlayer:
	var player := CrossfadePlayer.new()
	player.bank = bank
	player.bus = bus
	player.fade_time = time
	add_child(player)
	return player


func _wire(node: Node) -> void:
	if node.has_meta(&"wired") or not (node is BaseButton or node is Slider):
		return

	node.set_meta(&"wired", true)
	if node is BaseButton:
		node.mouse_entered.connect(_hover.bind(node))
		node.focus_entered.connect(_focused.bind(node))
		node.pressed.connect(_pressed.bind(node))
	elif node is Slider:
		node.value_changed.connect(_slid.bind(node))


func _hover(button: BaseButton) -> void:
	if not button.disabled and _gate("hover", hover_gap):
		_play(HOVER)


func _focused(button: BaseButton) -> void:
	if Time.get_ticks_msec() * 0.001 - _last_nav < 0.15:
		_hover(button)


func _pressed(button: BaseButton) -> void:
	_play(TOGGLE if button.toggle_mode else PRESS)


func _slid(_value: float, slider: Slider) -> void:
	if slider.has_focus() and _gate("slide", slide_gap):
		_play(SLIDE)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right")):
		_last_nav = Time.get_ticks_msec() * 0.001


func _gate(key: String, gap: float) -> bool:
	var now := Time.get_ticks_msec() * 0.001
	if now - _last.get(key, -10.0) < gap:
		return false

	_last[key] = now
	return true


func _play(sound: Dictionary) -> void:
	var bank := SoundBank.of("ui", sound.file)
	var voice := _ui[_next_ui]
	_next_ui = (_next_ui + 1) % _ui.size()
	voice.stream = bank.pick()
	voice.volume_db = sound.db + bank.gain_db
	voice.pitch_scale = sound.pitch
	voice.play()
