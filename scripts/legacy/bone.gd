extends PhysicalBone3D
class_name ActivePhysicalBone

var _force_requests: Array[Vector3] = []
var _torque_requests: Array[Vector3] = []


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	for force in _force_requests:
		state.apply_central_force(force)

	for torque in _torque_requests:
		state.apply_torque(torque)

	_force_requests.clear()
	_torque_requests.clear()


func request_force(force: Vector3) -> void:
	_force_requests.append(force)


func request_torque(torque: Vector3) -> void:
	_torque_requests.append(torque)
