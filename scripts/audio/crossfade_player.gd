class_name CrossfadePlayer
extends Node

class Slot extends AudioStreamPlayer:
	var fade := -80.0
	var gain := 0.0
	var tween: Tween

var bank: SoundBank.Bank
var bus: StringName
var fade_time := 4.0
var level_db := 0.0

var _slots: Array[Slot] = []
var _live: Slot
var _running := false


func _ready() -> void:
	for i in 2:
		var slot := Slot.new()
		slot.bus = bus
		add_child(slot)
		_slots.append(slot)


func _process(_delta: float) -> void:
	for slot in _slots:
		if slot.playing:
			slot.volume_db = slot.fade + slot.gain + level_db

	if _running and _live.stream.get_length() - _live.get_playback_position() <= fade_time:
		_fade(_live, -80.0, true)
		_begin(fade_time)


func start(time: float) -> void:
	if not _running:
		_running = true
		_begin(time)


func stop(time: float) -> void:
	_running = false
	for slot in _slots:
		if slot.playing:
			_fade(slot, -80.0, true, time)


func _begin(time: float) -> void:
	var slot := _slots[1] if _live == _slots[0] else _slots[0]
	slot.stream = bank.pick()
	slot.gain = bank.gain_db
	slot.fade = -80.0
	slot.volume_db = -80.0
	slot.play()
	_live = slot
	_fade(slot, 0.0, false, time)


func _fade(slot: Slot, to: float, then_stop: bool, time := fade_time) -> void:
	if slot.tween != null:
		slot.tween.kill()

	slot.tween = create_tween().set_ignore_time_scale()
	slot.tween.tween_property(slot, "fade", to, time)
	if then_stop:
		slot.tween.tween_callback(slot.stop)
