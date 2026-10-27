class_name StairClimber
extends Node

const LANE := -1.1
const LIMIT := 20.0

static var active: Array[StairClimber] = []
static var off_lane: Array[CharacterMovement] = []

@export var arrive := 0.12
@export var shift_speed := 2.6

var link: StairLink

var _movement: CharacterMovement
var _gait: GaitDriver
var _start := 0.0
var _goal := 0.0
var _time := 0.0


static func busy(other: StairLink, except: StairClimber = null) -> bool:
	for climber in active:
		if climber != except and climber.link.steps == other.steps:
			return true

	return false


func _init() -> void:
	process_physics_priority = -90


func _ready() -> void:
	_movement = get_parent() as CharacterMovement
	_gait = _movement.find_children("*", "GaitDriver", true, false)[0] as GaitDriver


func _exit_tree() -> void:
	active.erase(self)
	off_lane.erase(_movement)


func climbing() -> bool:
	return link != null


func ready_to_climb() -> bool:
	return _movement != null and link == null and _movement.health.alive and is_zero_approx(_movement.plane_z)


func begin(on: StairLink) -> bool:
	if not ready_to_climb() or busy(on):
		return false

	link = on
	_start = _movement.global_position.x
	_goal = on.goal_x()
	_time = 0.0
	on.hold(true)
	active.append(self)
	return true


func _physics_process(delta: float) -> void:
	if not _movement.health.alive:
		if link != null:
			active.erase(self)
			link = null

		return

	var lane := LANE if link != null else 0.0
	_shift(move_toward(_movement.plane_z, lane, shift_speed * delta) - _movement.plane_z)

	if link != null:
		_walk(delta)
	else:
		_idle()


func _idle() -> void:
	pass


func _reversed() -> bool:
	return false


func _walk(delta: float) -> void:
	var x := _movement.global_position.x
	if _reversed():
		var back := _start
		_start = _goal
		_goal = back

	_time += delta
	if absf(_goal - x) < arrive or _time > LIMIT:
		link.hold(false)
		active.erase(self)
		link = null
		return

	var input := _movement.input
	input.move = signf(_goal - x)
	input.sprint = false
	input.crouch = false
	input.jump = false


func _shift(dz: float) -> void:
	if not is_zero_approx(dz):
		var by := Vector3(0.0, 0.0, dz)
		_movement.plane_z += dz
		_movement.global_position += by
		_gait.shift_feet(by)
		for bone: PhysicalBone3D in _movement.find_children("*", "PhysicalBone3D", true, false):
			var rid := bone.get_rid()
			var placed: Transform3D = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM)
			placed.origin += by
			PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, placed)

	if is_zero_approx(_movement.plane_z):
		off_lane.erase(_movement)
	elif not off_lane.has(_movement):
		off_lane.append(_movement)
