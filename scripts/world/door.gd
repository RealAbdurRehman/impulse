class_name Door
extends Node3D

const MAX_SPIN := 8.0

@export var open_degrees := 95.0
@export var speed := 3.5
@export var reach := 1.3
@export var release := 1.8
@export var height := 3.0
@export var spring := 3.0
@export var damping := 2.2
@export var bullet_gain := 1.2

var _angle := 0.0
var _spin := 0.0
var _target := 0.0

@onready var _leaf := $Leaf as AnimatableBody3D


func hit(offset: Vector3, impulse: Vector3) -> void:
	_spin = clampf(_spin + (offset.z * impulse.x - offset.x * impulse.z) * bullet_gain, -MAX_SPIN, MAX_SPIN)


func _physics_process(delta: float) -> void:
	var opener := 0.0
	var holding := false
	for node in get_tree().get_nodes_in_group(CharacterMovement.GROUP):
		var body := node as CharacterMovement
		if not body.health.alive or absf(body.global_position.y - global_position.y) > height:
			continue

		var gap := body.global_position.x - global_position.x
		if absf(gap) < reach and opener == 0.0:
			opener = signf(gap)

		if absf(gap) < release:
			holding = true

	if _target == 0.0 and opener != 0.0:
		_target = -opener * deg_to_rad(open_degrees)
	elif not holding:
		_target = 0.0

	if _target != 0.0:
		_spin = 0.0
		_angle = move_toward(_angle, _target, speed * delta)
	else:
		var limit := deg_to_rad(open_degrees)
		_spin += (-spring * _angle - damping * _spin) * delta
		_angle += _spin * delta
		if absf(_angle) > limit:
			_angle = signf(_angle) * limit
			_spin = 0.0
		elif absf(_angle) < 0.002 and absf(_spin) < 0.01:
			_angle = 0.0
			_spin = 0.0

	_leaf.rotation.y = _angle
