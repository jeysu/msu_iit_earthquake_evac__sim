extends Area2D

var overlapping_agents: Array[Node2D] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("agents"):
		overlapping_agents.append(body)
		if body.state == "PANIC":
			Manager.agent_escaped(body)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("agents"):
		overlapping_agents.erase(body)

func despawn_panic_agents() -> void:
	for agent in overlapping_agents:
		if agent and agent.state == "PANIC":
			Manager.agent_escaped(agent)
