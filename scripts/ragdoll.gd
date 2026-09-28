extends Node3D

class_name ActiveRagdollController

@export var skeleton: Skeleton3D
@export var simulator: PhysicalBoneSimulator3D

@export var hips_bone_name: String = "mixamorig7_Hips"

@export_group("Balance")
@export var is_alive: bool = true

@export var balance_damping: float = 14.0
@export var balance_stiffness: float = 140.0

@export var target_standing_height: float = 1.0

func _ready() -> void:
	if not skeleton:
		skeleton = get_node_or_null("Skeleton3D") as Skeleton3D
	
	if not simulator:
		simulator = get_node_or_null("PhysicalBoneSimulator3D") as PhysicalBoneSimulator3D
	
	if simulator:
		simulator.physical_bones_start_simulation()

func _physics_process(_delta: float) -> void:
	if not is_alive:
		return
	
	_apply_upright_balance()

func _apply_upright_balance() -> void:
	if not simulator:
		return
	
	var hips: ActivePhysicalBone = simulator.get_node_or_null(hips_bone_name) as ActivePhysicalBone
	if hips:
		var rot_z: float = hips.global_rotation.z
		var torque_z: float = -rot_z * balance_stiffness - hips.angular_velocity.z * balance_damping
		
		hips.request_torque(Vector3(0, 0, torque_z))

func trigger_death(impact_impuse: Vector3 = Vector3.ZERO, hit_bone_name: String = "") -> void:
	is_alive = false
	
	if hit_bone_name != "" and simulator:
		var bone: PhysicalBone3D = simulator.get_node_or_null(hit_bone_name) as PhysicalBone3D
		if bone:
			bone.apply_impulse(impact_impuse)
