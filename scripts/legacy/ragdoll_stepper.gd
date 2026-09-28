extends Node3D
#class_name ActiveRagdollStepper
#
#@export var controller: ActiveRagdollController
#@export var left_foot_target: Node3D
#@export var right_foot_target: Node3D
#
#
#@export_group("Step Trigger")
#@export var step_distance: float = 0.35
#@export var step_cooldown: float = 0.25
#
#@export_group("Step Movement")
#@export var step_height: float = 0.15
#@export var step_duration: float = 0.22
#
#@export_group("Foot Offsets")
#@export var lateral_offset: float = 0.12
#@export var forward_offset: float = 0.05
#
#@export_group("Ground")
#@export var ground_mask: int = 1
#
#enum Foot {
#NONE,
#LEFT,
#RIGHT,
#}
#
#var _swinging: Foot = Foot.NONE
#var _step_timer: float = 0.0
#var _cooldown_timer: float = 0.0
#var _step_start: Vector3 = Vector3.ZERO
#var _step_end: Vector3 = Vector3.ZERO
#
#
#func _physics_process(delta: float) -> void:
#if not controller or not controller.is_alive:
#return
#
#_cooldown_timer = max(_cooldown_timer - delta, 0.0)
#
#if _swinging != Foot.NONE:
#_update_step(delta)
#else:
#_check_balance()
#
#
#func _check_balance() -> void:
#if _cooldown_timer > 0.0:
#return
#
#if not left_foot_target or not right_foot_target:
#return
#
#var com := controller.center_of_mass
#var mid := (left_foot_target.global_position + right_foot_target.global_position) * 0.5
#var drift_x := com.x - mid.x
#
#if abs(drift_x) > step_distance:
#_begin_step(Foot.RIGHT if drift_x > 0.0 else Foot.LEFT, com)
#
#
#func _begin_step(foot: Foot, com: Vector3) -> void:
#_swinging = foot
#_step_timer = 0.0
#
#var target_node := left_foot_target if foot == Foot.LEFT else right_foot_target
#_step_start = target_node.global_position
#
#var side := -lateral_offset if foot == Foot.LEFT else lateral_offset
#var ideal_x := com.x + side
#
#var ray_origin := Vector3(ideal_x, com.y + 0.5, com.z)
#var ray := PhysicsRayQueryParameters3D.new()
#
#ray.from = ray_origin
#ray.to = ray_origin - Vector3.UP * 3.0
#ray.collision_mask = ground_mask
#ray.exclude = controller._excluded_rids
#
#var result = get_world_3d().direct_space_state.intersect_ray(ray)
#_step_end = result.position if result else Vector3(ideal_x, _step_start.y, _step_start.z)
#
#
#func _update_step(delta: float) -> void:
#_step_timer += delta
#var t := clampf(_step_timer / step_duration, 0.0, 1.0)
#var smooth_t := smoothstep(0.0, 1.0, t)
#
#var flat := _step_start.lerp(_step_end, smooth_t)
#var arc := Vector3(flat.x, flat.y + sin(smooth_t * PI) * step_height, flat.z)
#
#var target_node := left_foot_target if _swinging == Foot.LEFT else right_foot_target
#target_node.global_position = arc
#
#if t >= 1.0:
#_swinging = Foot.NONE
#_cooldown_timer = step_cooldown
