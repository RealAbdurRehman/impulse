class_name Sway
extends Node

@export var amount := 0.014
@export var speed := 0.9

var _trees: Array[Node3D] = []
var _phase: Array[float] = []
var _time := 0.0


func add(tree: Node3D) -> void:
	_trees.append(tree)
	_phase.append(randf() * TAU)


func _process(delta: float) -> void:
	_time += delta
	for i in _trees.size():
		var t := _time * speed + _phase[i]
		_trees[i].rotation.x = sin(t) * amount
		_trees[i].rotation.z = sin(t * 0.8 + 1.3) * amount
