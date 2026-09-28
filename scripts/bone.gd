extends PhysicalBone3D

class_name ActivePhysicalBone

var torque_requests: Array[Vector3] = []

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	for torque in torque_requests:
		state.apply_torque(torque)
	
	torque_requests.clear()

func request_torque(torque: Vector3) -> void:
	torque_requests.append(torque)
