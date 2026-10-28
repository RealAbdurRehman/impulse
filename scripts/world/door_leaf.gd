class_name DoorLeaf
extends AnimatableBody3D


func apply_impulse(impulse: Vector3, offset: Vector3) -> void:
	(get_parent() as Door).hit(offset, impulse)
