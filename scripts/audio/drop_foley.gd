class_name DropFoley
extends Node

const MIN_LOSS := 1.6
const FULL_LOSS := 7.0
const HEAVY := 2

@export var voice: StringName = &"metal"
@export var pitch := 1.0
@export var gain_db := -6.0
@export var settle := 0.4
@export var cooldown := 0.18

var _body: RigidBody3D
var _before := Vector3.ZERO
var _age := 0.0
var _rest := 0.0


func _ready() -> void:
	_body = get_parent() as RigidBody3D
	_body.contact_monitor = true
	_body.max_contacts_reported = 4
	_body.body_entered.connect(_on_hit)


func _physics_process(delta: float) -> void:
	_age += delta
	_rest = maxf(_rest - delta, 0.0)
	_before = _body.linear_velocity


func _on_hit(other: Node) -> void:
	var loss := (_before - _body.linear_velocity).length()
	if loss < MIN_LOSS or _age < settle or _rest > 0.0:
		return

	_rest = cooldown
	var level := clampf(loss / FULL_LOSS, 0.0, 1.0)
	var at := _body.global_position
	var foley := Foley.of(self)
	foley.hit(at, Surfaces.of(other), level * 0.6, gain_db + 2.0, 1.0)
	foley.hit(at, voice, level, gain_db, pitch, HEAVY)
