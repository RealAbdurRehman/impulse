class_name FallDamage
extends Node

const SURVIVABLE := { &"Leg": 0.5 }
const LETHAL := { &"UpLeg": 0.3, &"Leg": 0.35, &"Foot": 0.3 }
const LETHAL_ARMS := { &"Arm": 0.25, &"ForeArm": 0.3, &"Hand": 0.3 }

@export var safe_speed := 8.0
@export var lethal_speed := 17.0
@export var damage_curve := 1.4
@export var min_damage := 6.0
@export var max_damage := 125.0

@export_group("Legs")
@export var buckle_speed := 9.5
@export var buckle_time := Vector2(0.45, 1.0)
@export_range(0.0, 1.0) var leg_grip := 0.3
@export_range(0.0, 1.0) var hip_grip := 0.5
@export var buckle_kick := 40.0

@export_group("Limp")
@export var limp_time := Vector2(2.0, 7.0)
@export_range(0.2, 1.0) var limp_scale := 0.65

@export_group("Gore")
@export var arm_severity := 1.5

@export_group("Dust")
@export var puffs := 7

var _movement: CharacterMovement
var _health: Health
var _ragdoll: ActiveRagdoll
var _limp := 0.0
var _limp_total := 1.0


func _init() -> void:
	process_physics_priority = -30


func _ready() -> void:
	_movement = get_parent() as CharacterMovement
	_health = _movement.health
	_ragdoll = _health.ragdoll as ActiveRagdoll
	_movement.landed.connect(_on_landed)
	_health.died.connect(set_physics_process.bind(false))


func _physics_process(delta: float) -> void:
	_limp = maxf(_limp - delta, 0.0)
	if _limp > 0.0:
		var input := _movement.input
		input.sprint = false
		input.jump = false
		input.jump_pressed = false

	_movement.speed_scale = lerpf(1.0, limp_scale, clampf(_limp / _limp_total, 0.0, 1.0))


func _on_landed(speed: float) -> void:
	if speed < safe_speed or not _health.alive:
		return

	_puff(speed)
	var severity := maxf(inverse_lerp(safe_speed, lethal_speed, speed), 0.0)
	var budget := lerpf(min_damage, max_damage, pow(severity, damage_curve))
	_injure(severity, budget)
	if not _health.alive or speed < buckle_speed:
		return

	var broken := clampf(inverse_lerp(buckle_speed, lethal_speed, speed), 0.0, 1.0)
	_limp_total = lerpf(limp_time.x, limp_time.y, broken)
	_limp = _limp_total
	_buckle(broken)


func _injure(severity: float, budget: float) -> void:
	var lethal := budget >= _health.current
	var shares := LETHAL if lethal else SURVIVABLE
	if lethal and severity >= arm_severity:
		shares = shares.merged(LETHAL_ARMS)

	var thrown := Vector3(-float(_movement.facing), 1.0, 0.0)
	_health.accident = true
	for bone in _ragdoll.physical_bones:
		var share: float = shares.get(StumpCap.part_of(bone), 0.0)
		if share > 0.0:
			var amount := budget * share * randf_range(0.8, 1.2) / _health.limb_multiplier
			_health.hit(amount, bone.global_position, thrown, bone)

	_health.accident = false


func _buckle(broken: float) -> void:
	var time := lerpf(buckle_time.x, buckle_time.y, broken)
	for bone in _ragdoll.physical_bones:
		var part := String(bone.bone_name).get_slice("_", 1)
		if part == "Hips":
			_ragdoll.flinch(bone, time, hip_grip)
			_ragdoll.kick(bone, Vector3.DOWN * buckle_kick * (0.6 + broken), Vector3.ZERO)
		elif part.ends_with("Leg") or part.ends_with("Foot"):
			_ragdoll.flinch(bone, time, leg_grip)


func _puff(speed: float) -> void:
	var dust := ImpactWorld.of(self).dust
	var style := Surfaces.style(&"concrete")
	var size := clampf(speed / lethal_speed, 0.4, 1.4)
	var feet := _movement.global_position + Vector3(0.0, 0.05, 0.0)
	for i in puffs:
		var side := -1.0 if i % 2 == 0 else 1.0
		dust.puff(feet, Vector3(side * randf_range(1.0, 3.2) * size, randf_range(0.2, 0.8), 0.0), style, size)
