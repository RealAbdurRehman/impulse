class_name SoundSet
extends Resource

@export var streams: Array[AudioStream] = []
@export var gains: PackedFloat32Array = PackedFloat32Array()

@export_range(-30.0, 12.0, 0.1) var volume_db := 0.0
@export_range(0.0, 6.0, 0.1) var volume_variation_db := 1.0
@export_range(0.0, 0.2, 0.005) var pitch_variation := 0.03

@export_range(0.0, 0.5, 0.005) var skip := 0.0

var gain_db := 0.0

var _last := -1


func pick() -> AudioStream:
	var i := randi() % streams.size()
	if streams.size() > 1 and i == _last:
		i = (i + 1 + randi() % (streams.size() - 1)) % streams.size()

	_last = i
	gain_db = gains[i] if i < gains.size() else 0.0
	return streams[i]
