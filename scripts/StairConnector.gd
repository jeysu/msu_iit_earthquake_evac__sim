extends Area2D

# Set these in the Inspector per stair node
@export var destination_floor: int    = 0
@export var destination_stair_name: String = "Stair_A"
@export var transit_time: float       = 3.5   # seconds to traverse stairs

# Stairwell capacity (Fundamental Diagram – queue-based)
@export var max_queue_size: int       = 6
var current_queue: int                = 0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("agents"):
		return
	if current_queue >= max_queue_size:
		# Stairwell full – agent waits nearby; re-check next frame
		_wait_and_retry(body)
		return
	_start_transit(body)

func _start_transit(agent: Node2D) -> void:
	current_queue += 1
	agent.set_physics_process(false)  # freeze agent during transit
	agent.visible = false             # "in the stairwell"

	# Apply density-dependent extra delay
	var density_penalty: float = float(current_queue) / float(max_queue_size) * 2.0
	var actual_transit = transit_time + density_penalty

	await get_tree().create_timer(actual_transit).timeout
	current_queue -= 1
	_deliver_to_floor(agent)

func _deliver_to_floor(agent: Node2D) -> void:
	var dest_floor: Node2D = Manager.floors.get(destination_floor)
	if dest_floor == null:
		return

	# Find the matching stair on the destination floor
	var dest_stair = dest_floor.get_node_or_null("StairConnectors/" + destination_stair_name)
	if dest_stair == null:
		return

	# Reparent agent to destination floor
	var old_parent = agent.get_parent()
	old_parent.remove_child(agent)
	dest_floor.get_node("Agents").add_child(agent)

	# Place at stair landing on the new floor
	agent.global_position = dest_stair.global_position + Vector2(20, 0)
	agent.assigned_floor  = destination_floor
	agent.visible         = true
	agent.set_physics_process(true)

	# Resume navigating to exit on the new floor
	agent._navigate_to_nearest_exit()

func _wait_and_retry(agent: Node2D) -> void:
	await get_tree().create_timer(0.5).timeout
	_on_body_entered(agent)  # try again
