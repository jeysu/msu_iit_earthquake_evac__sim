extends Node2D

@export var floor_index: int = 0
@export var occupancy: int   = 50

@onready var wander_points_node = $WanderPoints
@onready var agents_node        = $Agents

var wander_points: Array[Marker2D] = []
var agent_scene: PackedScene       = preload("res://scenes/Agent.tscn")

func _ready() -> void:
	for child in wander_points_node.get_children():
		if child is Marker2D:
			wander_points.append(child)
	Manager.register_floor(floor_index, self)

func spawn_agents() -> void:
	for i in range(occupancy):
		var a = agent_scene.instantiate()
		agents_node.add_child(a)
		a.add_to_group("agents")
		if wander_points.size() > 0:
			a.global_position = wander_points[randi() % wander_points.size()].global_position
		else:
			a.global_position = global_position
		a.assigned_floor = floor_index

func get_random_wander_point() -> Vector2:
	if wander_points.is_empty():
		return global_position
	return wander_points[randi() % wander_points.size()].global_position
