class_name SprintStyle
extends RefCounted

var gun_degrees := 0.0
var hand_degrees := 0.0
var reach := 0.0
var height := 0.0
var elbow_degrees := -60.0
var twist_release := 0.0
var lag := 1.0
var lag_hz := 5.0
var pitch_gain := 4.0
var heft := 0.5


static func of(stats: WeaponStats) -> SprintStyle:
	var style := SprintStyle.new()
	if stats.manual_cycle and stats.pellets <= 1:
		style.gun_degrees = 40.0
		style.hand_degrees = 6.0
		style.reach = 0.18
		style.height = -0.36
		style.elbow_degrees = -30.0
		style.twist_release = 0.7
		style.lag_hz = 4.0
		style.pitch_gain = 5.0
		style.heft = 1.0
	elif stats.pellets > 1:
		style.gun_degrees = 36.0
		style.hand_degrees = 6.0
		style.reach = 0.2
		style.height = -0.34
		style.elbow_degrees = -30.0
		style.twist_release = 0.7
		style.lag_hz = 4.5
		style.pitch_gain = 4.5
		style.heft = 0.75
	elif stats.automatic:
		style.gun_degrees = 36.0
		style.hand_degrees = 6.0
		style.reach = 0.2
		style.height = -0.34
		style.elbow_degrees = -30.0
		style.twist_release = 0.7
		style.lag_hz = 5.0
		style.pitch_gain = 4.0
		style.heft = 0.6
	else:
		style.gun_degrees = 64.0
		style.hand_degrees = 8.0
		style.reach = 0.2
		style.height = -0.22
		style.elbow_degrees = -12.0
		style.twist_release = 0.4
		style.lag_hz = 6.0
		style.pitch_gain = 3.5
		style.heft = 0.2

	return style
