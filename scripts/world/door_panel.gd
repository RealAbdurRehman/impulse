class_name DoorPanel
extends AnimatableBody3D

var door: Door
var marks: ImpactMarks


func apply_impulse(impulse: Vector3, offset: Vector3) -> void:
	door.hit(global_position + offset, impulse)
