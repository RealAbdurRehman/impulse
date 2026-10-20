class_name NoiseSource
extends Node

signal bang(at: Vector3, radius: float)

const RUN_RADIUS := 9.0
const WALK_RADIUS := 4.0
const CREEP_RADIUS := 1.5
const RUN_SPEED := 1.4
const MOVE_SPEED := 0.3
const HARD_LANDING := 3.0

var radius := 0.0

var _body: CharacterMovement
var _carrier: WeaponCarrier
var _weapon: Weapon
var _was_grounded := true
var _fall := 0.0


static func of(body: CharacterMovement) -> NoiseSource:
	var found := body.get_node_or_null("Noise") as NoiseSource
	if found == null:
		found = NoiseSource.new()
		found.name = "Noise"
		found._body = body
		found._carrier = body.get_node("WeaponCarrier") as WeaponCarrier
		body.add_child.call_deferred(found)

	return found


static func shot_radius(stats: WeaponStats) -> float:
	if stats.manual_cycle and stats.pellets <= 1:
		return 45.0

	if stats.pellets > 1:
		return 40.0

	return 35.0 if stats.automatic else 28.0


func _physics_process(_delta: float) -> void:
	if _carrier.weapon != _weapon:
		_weapon = _carrier.weapon
		_weapon.fired.connect(_on_fired)

	var speed := absf(_body.velocity.x)
	radius = 0.0
	if _body.grounded and speed > MOVE_SPEED:
		if _body.crouching:
			radius = CREEP_RADIUS
		else:
			radius = RUN_RADIUS if speed > RUN_SPEED else WALK_RADIUS

	if _body.grounded:
		if not _was_grounded and _fall < -HARD_LANDING:
			bang.emit(_body.global_position, 4.0 - _fall * 0.8)

		_fall = 0.0
	else:
		_fall = minf(_fall, _body.velocity.y)

	_was_grounded = _body.grounded


func _on_fired(_muzzle: Transform3D) -> void:
	bang.emit(_body.global_position, shot_radius(_weapon.stats))
