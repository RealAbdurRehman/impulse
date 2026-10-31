class_name ScenarioRun
extends CanvasLayer

const CLEAR_DELAY := 1.2
const BANNER_HOLD := 2.2
const BANNER_FADE := 0.8
const CLEARED_HOLD := 8.0
const RALLY_GAP := 1.0
const RALLY_RANGE := 12.0

var spec: Dictionary

var _world: Sandbox
var _menu: SpawnMenu
var _level: ScenarioLevel
var _waves: Array[ScenarioWave] = []
var _queue: Array = []
var _wave := -1
var _wait := 0.0
var _clock := 0.0
var _time := 0.0
var _pending := 0
var _assault := false
var _rally := 0.0
var _done := false
var _status: Label
var _banner: VBoxContainer
var _headline: Label
var _detail: Label
var _banner_tween: Tween


func _ready() -> void:
	layer = 20
	_world = get_parent() as Sandbox
	_menu = _world.get_node("SpawnMenu") as SpawnMenu
	_level = (load(spec.scene) as PackedScene).instantiate() as ScenarioLevel
	_world.add_child(_level)
	for each in _level.find_children("*", "ScenarioWave", true, false):
		_waves.append(each as ScenarioWave)

	for each in _level.find_children("*", "ScenarioMarker", true, false):
		if not each.get_parent() is ScenarioWave:
			(each as ScenarioMarker).release(_menu)

	_wait = _waves[0].pause
	_build_hud()
	_show(String(spec.title).to_upper(), "")


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if _done and key != null and key.pressed and not key.echo and key.keycode == KEY_TAB:
		_banner_tween.kill()
		_banner.modulate.a = 0.0


func _physics_process(delta: float) -> void:
	if _done:
		return

	if not _world.player.health.alive:
		return

	_clock += delta
	_release_due()
	_pending = _count_hostiles() + _queue.size()
	if _wave >= 0:
		_time += delta

	_status.text = _status_text() if _wave >= 0 else ""
	_rally -= delta
	if _assault and _rally <= 0.0:
		_rally = RALLY_GAP
		_rally_foes()

	var last := _wave + 1 >= _waves.size()
	if _wave >= 0 and _pending > (0 if last else _waves[_wave + 1].carry_over):
		_wait = CLEAR_DELAY if last else _waves[_wave + 1].pause
		return

	_wait -= delta
	if _wait > 0.0:
		return

	if last:
		_finish()
	else:
		_begin(_wave + 1)


func _begin(index: int) -> void:
	_wave = index
	var wave := _waves[index]
	_assault = wave.assault
	for each in wave.find_children("*", "ScenarioMarker", false, false):
		var foe := each as ScenarioFoe
		if foe != null and foe.delay > 0.0:
			_queue.append([_clock + foe.delay, foe])
		else:
			(each as ScenarioMarker).release(_menu)

	if index > 0:
		_show("FINAL WAVE" if index + 1 == _waves.size() else "WAVE %d" % (index + 1), "")


func _release_due() -> void:
	for entry: Array in _queue.duplicate():
		if entry[0] <= _clock:
			_queue.erase(entry)
			(entry[1] as ScenarioFoe).release(_menu)


func _finish() -> void:
	_done = true
	var improved := Scenarios.record(spec.id, _time)
	var line := "TIME %s" % Scenarios.clock(_time)
	line += "   NEW BEST" if improved else "   BEST %s" % Scenarios.clock(Scenarios.best(spec.id))
	_status.text = ""
	_show("CLEARED", line, true)
	GameAudio.of(get_tree()).victory()
	_detail.text += "\n\nTab to edit  ·  Esc to restart or leave"


func _rally_foes() -> void:
	var at := _world.player.global_position
	for node in get_tree().get_nodes_in_group(CharacterMovement.GROUP):
		var body := node as CharacterMovement
		if body.health.team == SpawnMenu.ENEMY_TEAM and body.health.alive \
				and absf(body.global_position.x - at.x) > RALLY_RANGE:
			(body.get_node("EnemyInput") as EnemyInput).alert(at)


func _count_hostiles() -> int:
	var count := 0
	var mine := _world.player.health.team
	for node in get_tree().get_nodes_in_group(CharacterMovement.GROUP):
		var body := node as CharacterMovement
		if body.health.alive and body.health.team != mine and not body.is_queued_for_deletion():
			count += 1

	return count


func _status_text() -> String:
	var line := "HOSTILES  %d" % _pending
	if _waves.size() > 1:
		line = "WAVE  %d / %d      %s" % [_wave + 1, _waves.size(), line]

	return "%s      %s" % [line, Scenarios.clock(_time)]


func _build_hud() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_top", 28)
	add_child(margin)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	margin.add_child(box)

	var title := _label(box, &"SectionLabel", 20)
	title.text = String(spec.title).to_upper()
	_status = _label(box, &"Label", 26)

	_banner = VBoxContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_banner.modulate.a = 0.0
	margin.add_child(_banner)
	_headline = _label(_banner, &"HeadingLabel", 96)
	_detail = _label(_banner, &"TaglineLabel", 30)


func _label(parent: Control, variation: StringName, size: int) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.add_theme_font_size_override("font_size", size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _show(headline: String, detail: String, hold := false) -> void:
	_headline.text = headline
	_detail.text = detail
	_banner.modulate.a = 1.0
	if _banner_tween != null:
		_banner_tween.kill()

	_banner_tween = create_tween()
	_banner_tween.tween_interval(CLEARED_HOLD if hold else BANNER_HOLD)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, BANNER_FADE)
