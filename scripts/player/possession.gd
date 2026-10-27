class_name Possession
extends RefCounted

const PLAYER := preload("res://scenes/player.tscn")


static func take(menu: SpawnMenu, target: CharacterMovement) -> void:
	var world := menu.world
	var tree := world.get_tree()
	var old := world.player
	var alive := old.health.alive
	if alive:
		old.get_node("PlayerSlowMotion").free()

	var next := _embody(world, target, old)
	world.take_over(next)
	if alive:
		_stand_in(menu, old)
	else:
		_retire(old)

	for node in tree.get_nodes_in_group(Targeter.GROUP):
		(node as Targeter).player = next

	for node in tree.get_nodes_in_group(&"enemies"):
		_rebind(node as EnemyInput, old, next)

	Targeter.squad.clear()
	Roster.remove(tree, target, next)
	if alive:
		old.free()


static func _embody(world: Sandbox, target: CharacterMovement, old: CharacterMovement) -> CharacterMovement:
	var gun := _gun(target)
	var next := PLAYER.instantiate() as CharacterMovement
	(next.get_node("Weapon") as Weapon).stats = gun.stats
	(next.get_node("BodyLook") as BodyLook).style = (target.get_node("BodyLook") as BodyLook).style
	next.position = target.global_position
	next.rotation.y = PI * 0.5 * float(target.facing)
	old.name = &"Former"
	world.add_child(next)
	next.health.team = target.health.team
	next.health.current = target.health.current
	_gun(next).ammo = gun.ammo
	return next


static func _stand_in(menu: SpawnMenu, old: CharacterMovement) -> void:
	var gun := _gun(old)
	var kind := SpawnKind.new()
	kind.weapon = gun.stats
	var successor := menu.spawn(old.global_position, kind, old.health.team)
	successor.facing = old.facing
	successor.rotation.y = PI * 0.5 * float(old.facing)
	successor.health.current = old.health.current
	_gun(successor).ammo = gun.ammo


static func _retire(old: CharacterMovement) -> void:
	old.get_node("PlayerHud").free()
	for mark in old.find_children("*", "VisibilityMark", false, false):
		mark.free()


static func _rebind(brain: EnemyInput, old: CharacterMovement, next: CharacterMovement) -> void:
	var friendly := brain.health.team == next.health.team
	if brain.leader == old:
		brain.leader = next if friendly else null

	var chasing := brain.target == old
	brain.forget(old, next)
	if chasing:
		brain.hostile = not friendly

	Roster.align(brain, next.health.team)


static func _gun(body: CharacterMovement) -> Weapon:
	return (body.get_node("WeaponCarrier") as WeaponCarrier).weapon
