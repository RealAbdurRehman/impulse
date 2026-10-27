class_name Roster
extends RefCounted

const ALLY_SIGHT := 30.0
const FOE_SIGHT := 20.0


static func align(brain: EnemyInput, mine: StringName) -> void:
	var friendly := brain.health.team == mine
	brain.fair_play = not friendly
	brain.sight_range = ALLY_SIGHT if friendly else FOE_SIGHT


static func remove(tree: SceneTree, body: CharacterMovement, fallback: CharacterMovement) -> void:
	Targeter.squad.erase(body.get_node_or_null("EnemyInput"))
	for node in tree.get_nodes_in_group(&"enemies"):
		(node as EnemyInput).forget(body, fallback)

	body.process_mode = Node.PROCESS_MODE_DISABLED
	body.queue_free()


static func clear(tree: SceneTree, player: CharacterMovement, allies: bool) -> void:
	for node in tree.get_nodes_in_group(CharacterMovement.GROUP):
		var body := node as CharacterMovement
		if body == player or body.is_queued_for_deletion():
			continue

		if (body.health.team == player.health.team) == allies:
			remove(tree, body, player)
