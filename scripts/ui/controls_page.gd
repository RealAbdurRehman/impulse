class_name ControlsPage
extends MarginContainer

signal back

const SECTIONS := {
	"MOVEMENT": [
		["A / D   ← / →", "Move"],
		["Space", "Jump"],
		["Shift", "Sprint"],
		["Ctrl / C", "Crouch"],
	],
	"COMBAT": [
		["Mouse", "Aim"],
		["Left click", "Shoot"],
		["Right click", "Scope"],
		["R", "Reload"],
		["B", "Fire mode"],
		["E", "Pick up / swap weapon"],
		["F", "Bandage"],
		["Q", "Slow motion"],
		["V", "Allies follow / hold"],
	],
	"EDITOR": [
		["Tab", "Open / close editor"],
		["Space", "Run / freeze world"],
		["X", "Delete tool"],
		["P", "Possess tool"],
		["Right click", "Cancel tool"],
		["WASD / arrows", "Pan camera"],
		["Wheel   + / −", "Zoom"],
		["F", "Centre on player"],
	],
	"GAME": [
		["Esc", "Pause"],
	],
}

var _back: Button


func _ready() -> void:
	theme_type_variation = &"PageMargin"

	var box := VBoxContainer.new()
	box.theme_type_variation = &"PageBox"
	add_child(box)

	var heading := Label.new()
	heading.theme_type_variation = &"HeadingLabel"
	heading.text = "CONTROLS"
	box.add_child(heading)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 72)
	box.add_child(columns)

	var left := VBoxContainer.new()
	var right := VBoxContainer.new()
	left.add_theme_constant_override("separation", 28)
	right.add_theme_constant_override("separation", 28)
	columns.add_child(left)
	columns.add_child(right)
	left.add_child(_section("MOVEMENT"))
	left.add_child(_section("COMBAT"))
	right.add_child(_section("EDITOR"))
	right.add_child(_section("GAME"))

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


func _section(title: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	var label := Label.new()
	label.theme_type_variation = &"SectionLabel"
	label.text = title
	section.add_child(label)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 36)
	grid.add_theme_constant_override("v_separation", 8)
	section.add_child(grid)

	for row in SECTIONS[title]:
		var key := Label.new()
		key.text = row[0]
		key.custom_minimum_size = Vector2(190, 0)
		grid.add_child(key)

		var action := Label.new()
		action.theme_type_variation = &"MutedLabel"
		action.text = row[1]
		grid.add_child(action)

	return section


func _on_visibility_changed() -> void:
	if visible:
		_back.grab_focus.call_deferred()
