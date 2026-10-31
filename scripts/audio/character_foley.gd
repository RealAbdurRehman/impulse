class_name CharacterFoley
extends Node

@export var npc_db := -3.0
@export var crouch_loudness := 0.55
@export var recovery_loudness := 0.5
@export var shuffle_speed := 0.15
@export var shuffle_loudness := 0.2
@export var min_land_speed := 1.4
@export var full_land_speed := 9.0

var _gait: GaitDriver
var _body: CharacterMovement
var _npc := false


func _ready() -> void:
	_gait = get_parent() as GaitDriver
	_body = _gait.character
	_npc = not _body.input is PlayerInput
	_gait.stepped.connect(_on_step)
	_body.jumped.connect(_on_jump)
	_body.landed.connect(_on_land)


func _on_step(at: Vector3, recovery: bool) -> void:
	var loud := clampf(absf(_body.move_speed) / _body.run_speed, 0.25, 1.0)
	if absf(_body.move_speed) < shuffle_speed:
		if _npc:
			return

		loud = shuffle_loudness
	elif _body.crouching:
		loud *= crouch_loudness

	if recovery:
		loud *= recovery_loudness

	Foley.of(self).step(at, _surface(at), loud, _db(), _npc)


func _on_jump() -> void:
	var at := _body.global_position
	Foley.of(self).step(at, _surface(at), 0.55, _db(), _npc)


func _on_land(speed: float) -> void:
	var at := _body.global_position
	var surface := _surface(at)
	var foley := Foley.of(self)
	var level := clampf(inverse_lerp(min_land_speed, full_land_speed, speed), 0.0, 1.0)
	foley.step(at, surface, clampf(0.5 + level, 0.0, 1.0), _db(), _npc)
	if speed < min_land_speed:
		return

	foley.hit(at, surface, level * 0.9, _db())
	foley.thud(at + Vector3.UP * 0.5, level, _db())


func _db() -> float:
	return npc_db if _npc else 0.0


func _surface(at: Vector3) -> StringName:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.4, at + Vector3.DOWN * 0.6, _body.ground_mask)
	var found := _body.get_world_3d().direct_space_state.intersect_ray(query)
	return Surfaces.of(found.collider) if not found.is_empty() else &"concrete"
