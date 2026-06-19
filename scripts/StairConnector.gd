extends Area2D

@export var destination_floor: int    = 0
@export var destination_stair_name: String = "Stair_A"
@export var transit_time: float       = 1

@export var max_queue_size: int       = 20
var current_queue: int                = 0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("agents"):
		return
	if current_queue >= max_queue_size:
		_wait_and_retry(body)
		return
	_start_transit(body)

func _start_transit(agent: Node2D) -> void:
	current_queue += 1
	agent.set_physics_process(false)
	agent.visible = false

	var density_penalty: float = float(current_queue) / float(max_queue_size) * 2.0
	var actual_transit = transit_time + density_penalty

	await get_tree().create_timer(actual_transit).timeout
	current_queue -= 1

	if not is_instance_valid(agent):
		return
	_deliver_to_floor(agent)

func _deliver_to_floor(agent: Node2D) -> void:
	var dest_floor: Node2D = Manager.floors.get(destination_floor)
	if dest_floor == null:
		return

	var dest_stair = dest_floor.get_node_or_null("StairConnectors/" + destination_stair_name)
	if dest_stair == null:
		return

	var old_parent = agent.get_parent()
	old_parent.remove_child(agent)
	dest_floor.get_node("Agents").add_child(agent)

	var landing_shape = dest_stair.get_node_or_null("CollisionShape2D")
	var landing_pos = landing_shape.global_position if landing_shape else dest_stair.global_position
	agent.global_position = landing_pos + Vector2(20, 0)

	agent.assigned_floor  = destination_floor
	agent.visible         = true
	
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	agent.set_physics_process(true)
	agent._navigate_to_nearest_exit()

func _wait_and_retry(agent: Node2D) -> void:
	if agent.has_method("set_physics_process"):
		agent.velocity = Vector2.LEFT * 50
		agent.move_and_slide()
