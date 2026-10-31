class_name SoundBank
extends RefCounted

const ROOT := "res://assets/audio/world/"
const EXTENSIONS := ["ogg", "wav", "mp3"]

static var _banks := { }
static var _levels: Dictionary = (load(ROOT + "levels.json") as JSON).data


class Bank extends RefCounted:
	var streams: Array[AudioStream] = []
	var gains := PackedFloat32Array()
	var gain_db := 0.0

	var _last := -1

	func pick(from := 0, to := -1) -> AudioStream:
		var end := streams.size() if to < 0 else mini(to, streams.size())
		var count := end - from
		var i := from + randi() % count
		if count > 1 and i == _last:
			i = from + (i - from + 1 + randi() % (count - 1)) % count

		_last = i
		gain_db = gains[i]
		return streams[i]


static func of(folder: String, prefix := "") -> Bank:
	var key := folder + "/" + prefix
	if not _banks.has(key):
		_banks[key] = _load(folder, prefix)

	return _banks[key]


static func warm() -> void:
	for folder in ["footsteps/concrete", "footsteps/metal", "footsteps/wood", "impacts/body", "impacts/concrete", "impacts/glass", "impacts/metal", "impacts/plastic", "impacts/wood", "ui"]:
		of(folder)


static func _load(folder: String, prefix: String) -> Bank:
	var bank := Bank.new()
	var names := Array(ResourceLoader.list_directory(ROOT + folder))
	names.sort()
	for file: String in names:
		if file.get_extension() in EXTENSIONS and file.begins_with(prefix):
			bank.streams.append(load(ROOT + folder + "/" + file))
			bank.gains.append(_levels.get(folder + "/" + file, 0.0))

	return bank
