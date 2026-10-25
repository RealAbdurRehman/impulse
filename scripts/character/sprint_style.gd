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
	style.gun_degrees = stats.sprint_gun_degrees
	style.hand_degrees = stats.sprint_hand_degrees
	style.reach = stats.sprint_reach
	style.height = stats.sprint_height
	style.elbow_degrees = stats.sprint_elbow_degrees
	style.twist_release = stats.sprint_twist_release
	style.lag = stats.sprint_lag
	style.lag_hz = stats.sprint_lag_hz
	style.pitch_gain = stats.sprint_pitch_gain
	style.heft = stats.sprint_heft
	return style
