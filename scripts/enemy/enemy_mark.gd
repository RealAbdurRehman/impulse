class_name EnemyMark
extends Label3D

const CALM := Color(1.0, 0.95, 0.3)
const ALARM := Color(1.0, 0.25, 0.1)
const FROM := 0.1


func _init() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	fixed_size = false
	font_size = 64
	outline_size = 14
	position = Vector3(0.0, 2.1, 0.0)
	visible = false


func show_state(awareness: float, alarm: bool) -> void:
	visible = alarm or awareness >= FROM
	if not visible:
		return

	if alarm:
		text = "!"
		modulate = ALARM
		pixel_size = 0.0075
	else:
		text = "?"
		modulate = CALM.lerp(ALARM, awareness)
		pixel_size = lerpf(0.003, 0.0065, awareness)
