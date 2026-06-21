extends Area2D
## Exit.gd - Detects evacuated agents reaching a safe exit.
## Attach to: each "Exit" Area2D node under a Floor's "Exits" container.
##
## NOTE: Agent.tscn has no PhysicsBody, only an Area2D (for precise, cheap
## overlap detection), so this listens for area_entered (Area<->Area),
## not body_entered.
##
## Thesis ref: Chapter 3.4.2 "The Environment (Digitization Layer)", Listing 3.1.

@export var is_blocked: bool = false  # Used by the "Constrained Scenario" (3.5).


func _ready() -> void:
	add_to_group("exits")
	area_entered.connect(_on_area_entered)


## The Exit Area2D node itself always sits at local (0,0) under "Exits" - the
## real-world location is entirely encoded in the child CollisionShape2D's
## position. Pathfinding targets must use this, not global_position directly.
func get_target_position() -> Vector2:
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			return child.global_position
	return global_position


func _on_area_entered(area: Area2D) -> void:
	if is_blocked:
		return

	var agent := area.get_parent()
	if agent == null or not is_instance_valid(agent):
		return
	if not agent.is_in_group("agents"):
		return
	if not agent.has_method("on_escaped"):
		return
	if agent.has_method("is_active") and not agent.is_active():
		return  # Already claimed by an overlapping Exit/StairConnector this frame.

	Manager.agent_escaped(agent)
	agent.on_escaped()


func set_blocked(value: bool) -> void:
	is_blocked = value
	# Visual feedback if this exit gets disabled for a Constrained Scenario run.
	modulate = Color(0.5, 0.5, 0.5, 0.6) if value else Color(1, 1, 1, 1)
