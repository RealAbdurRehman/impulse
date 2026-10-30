class_name ScenariosPage
extends MarginContainer

signal back
signal chosen(id: StringName)

var _first: Button
var _back: Button


func _ready() -> void:
	theme_type_variation = &"PageMargin"

	var box := VBoxContainer.new()
	box.theme_type_variation = &"PageBox"
	add_child(box)

	var heading := Label.new()
	heading.theme_type_variation = &"HeadingLabel"
	heading.text = "SCENARIOS"
	box.add_child(heading)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 26)
	box.add_child(list)
	for spec: Dictionary in Scenarios.LIST:
		list.add_child(_entry(spec))

	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(fill)

	_back = Button.new()
	_back.text = "Back"
	_back.custom_minimum_size = Vector2(200, 0)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_back.pressed.connect(back.emit)
	box.add_child(_back)

	visibility_changed.connect(_on_visibility_changed)


func _entry(spec: Dictionary) -> VBoxContainer:
	var entry := VBoxContainer.new()
	entry.add_theme_constant_override("separation", 6)

	var play := Button.new()
	play.text = spec.title
	play.alignment = HORIZONTAL_ALIGNMENT_LEFT
	play.custom_minimum_size = Vector2(520, 0)
	play.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	play.pressed.connect(chosen.emit.bind(spec.id))
	entry.add_child(play)
	if _first == null:
		_first = play

	var best := Scenarios.best(spec.id)
	if best > 0.0:
		var record := Label.new()
		record.theme_type_variation = &"SectionLabel"
		record.text = "BEST  %s" % Scenarios.clock(best)
		entry.add_child(record)

	return entry


func _on_visibility_changed() -> void:
	if visible:
		_first.grab_focus.call_deferred()
