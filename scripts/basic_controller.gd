extends CharacterBody3D

@export var speed: float = 8.0
@export var acceleration: float = 20.0
@export var friction: float = 15.0

@export var jump_force: float = 10.0
@export var gravity: float = 24.0

@export var prop_push_force: float = 280.0


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force

	var input_dir: float = Input.get_axis("move_left", "move_right")
	if input_dir != 0.0:
		velocity.x = move_toward(velocity.x, input_dir * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	velocity.z = 0.0
	global_position.z = 0.0

	move_and_slide()
	_handle_prop_pushing()


func _handle_prop_pushing() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var body := collision.get_collider()

		if body is RigidBody3D:
			var normal := collision.get_normal()

			if abs(normal.x) > 0.5 and abs(normal.y) < 0.5:
				var push_dir := -collision.get_normal()
				body.apply_central_force(push_dir * prop_push_force * body.mass)

				if abs(body.linear_velocity.x) > speed:
					body.linear_velocity.x = sign(body.linear_velocity.x) * speed
