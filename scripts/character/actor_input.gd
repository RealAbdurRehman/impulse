class_name ActorInput
extends Node
## What a character wants to do this physics tick. PlayerInput fills it from
## the keyboard and mouse, an enemy brain fills it from its own decisions;
## movement, gait and weapon scripts only ever read these fields.

var move := 0.0
var crouch := false
var sprint := false
var jump := false
var fire := false
var aim := false
var reload := false
var fire_mode := false
var interact := false

## World point the character looks and shoots at, on its own plane.
var aim_point := Vector3.ZERO
var has_aim := false

var jump_pressed := false
var jump_released := false
var fire_pressed := false
var reload_pressed := false
var fire_mode_pressed := false
var interact_pressed := false

var _was_jump := false
var _was_fire := false
var _was_reload := false
var _was_fire_mode := false
var _was_interact := false


func _init() -> void:
	process_physics_priority = -100


func _physics_process(_delta: float) -> void:
	poll()

	jump_pressed = jump and not _was_jump
	jump_released = _was_jump and not jump
	fire_pressed = fire and not _was_fire
	reload_pressed = reload and not _was_reload
	fire_mode_pressed = fire_mode and not _was_fire_mode
	interact_pressed = interact and not _was_interact

	_was_jump = jump
	_was_fire = fire
	_was_reload = reload
	_was_fire_mode = fire_mode
	_was_interact = interact


## Sets the fields above for this tick. The press and release edges are
## worked out from them afterwards. A brain that lives in another node can set
## them from its own _physics_process instead; the edges arrive a tick later.
func poll() -> void:
	pass
