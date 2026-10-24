class_name PlayerSlowMotion
extends Node

const CLEAR_HZ := 20500.0

@export var health: Health

@export_range(0.05, 1.0) var time_scale := 0.2
@export var ease_in := 14.0
@export var ease_out := 7.0

@export_range(0.05, 1.0) var death_time_scale := 0.3

@export_group("Audio")
@export_range(0.0, 1.0) var pitch_follow := 0.7
@export var muffled_hz := 2800.0

var active := false
var amount := 0.0

var _filter := AudioEffectLowPassFilter.new()
var _slot := 0
var _dying := false
var _last_usec := 0


func _ready() -> void:
	_filter.cutoff_hz = CLEAR_HZ
	AudioServer.add_bus_effect(0, _filter)
	_slot = AudioServer.get_bus_effect_count(0) - 1
	AudioServer.set_bus_effect_enabled(0, _slot, false)

	health.died.connect(_on_died)
	_last_usec = Time.get_ticks_usec()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	AudioServer.playback_speed_scale = 1.0
	AudioServer.remove_bus_effect(0, _slot)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"slow_motion"):
		active = not active


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real := minf(float(now - _last_usec) * 0.000001, 0.1)
	_last_usec = now

	var target := death_time_scale if _dying else (time_scale if active else 1.0)
	var rate := ease_in if active or _dying else ease_out
	var eased := lerpf(Engine.time_scale, target, 1.0 - exp(-rate * real))
	Engine.time_scale = target if absf(eased - target) < 0.003 else eased

	amount = (1.0 - Engine.time_scale) / (1.0 - time_scale)
	AudioServer.playback_speed_scale = lerpf(1.0, Engine.time_scale, pitch_follow)
	AudioServer.set_bus_effect_enabled(0, _slot, amount > 0.001)
	_filter.cutoff_hz = exp(lerpf(log(CLEAR_HZ), log(muffled_hz), amount))


func _on_died() -> void:
	active = false
	_dying = true
	set_process_unhandled_input(false)
