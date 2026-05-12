extends Node2D

@export var floor_index: int = 0
@export var occupancy: int   = 50  # agents to spawn

@onready var wander_points_node = $WanderPoints
@onready var agents_node        = $Agents

var wander_points: Array[Marker2D] = []
var agent_scene: PackedScene       = preload("res://scenes/Agent.tscn")

func _ready() -> void:
	# Collect wander points
	for child in wander_points_node.get_children():
		if child is Marker2D:
			wander_points.append(child)

	# Hook up all exits on this floor
	for exit in $Exits.get_children():
		exit.body_entered.connect(_on_exit_body_entered.bind(exit))

	# Register exits with manager
	Manager.register_floor(floor_index, self)

func spawn_agents() -> void:
	for i in range(occupancy):
		var a = agent_scene.instantiate()
		agents_node.add_child(a)
		a.add_to_group("agents")
		# Spawn at a random wander point
		if wander_points.size() > 0:
			a.global_position = wander_points[randi() % wander_points.size()].global_position
		a.assigned_floor = floor_index

func get_random_wander_point() -> Vector2:
	if wander_points.is_empty():
		return global_position
	return wander_points[randi() % wander_points.size()].global_position

func _on_exit_body_entered(body: Node2D, _exit: Area2D) -> void:
	if body.is_in_group("agents"):
		Manager.agent_escaped(body)
