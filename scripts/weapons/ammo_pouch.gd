class_name AmmoPouch
extends Node

signal changed

const LIMITS := {
	&"pistol": 85,
	&"rifle": 150,
	&"sniper": 30,
	&"shotgun": 36,
}
const NAMES := {
	&"pistol": "PISTOL",
	&"rifle": "RIFLE",
	&"sniper": "SNIPER",
	&"shotgun": "SHOTGUN",
}

var counts := { }


func count(type: StringName) -> int:
	return int(counts.get(type, 0))


func room(type: StringName) -> int:
	return int(LIMITS[type]) - count(type)


func take(type: StringName, want: int) -> int:
	var got := mini(want, count(type))
	if got > 0:
		counts[type] = count(type) - got
		changed.emit()

	return got


func add(type: StringName, amount: int) -> int:
	var got := clampi(amount, 0, room(type))
	if got > 0:
		counts[type] = count(type) + got
		changed.emit()

	return got
