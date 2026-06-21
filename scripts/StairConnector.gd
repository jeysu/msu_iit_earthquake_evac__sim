extends Area2D
## StairConnector.gd - Models vertical evacuation through a stairwell using
## the "Connector Model" (teleport-queue) described in the thesis, rather
## than continuous 3D physics.
##
## Attach to: each "Stair_X_Y" Area2D node under a Floor's "StairConnectors"
## container (e.g. in CASS_0..CASS_3.tscn).
##
## Expected exported properties already set in your .tscn files:
##   destination_floor        (int)    - floor_index of the destination Floor.
##   destination_marker_name  (String) - name of the Marker2D under the
##                                        destination Floor's WanderPoints
##                                        node where the agent reappears.
##
## Thesis ref: Chapter 3.4.6 "Vertical Evacuation and Stairwell Dynamics"
## (3.4.6.1 Connector Model, 3.4.6.2 Funnel Simulation, 3.4.6.3
## Density-Dependent Velocity).
##
## LIMITATION (documented, not hidden): each StairConnector models a single
## floor-to-floor hop in isolation. The thesis's 3.4.6.4 "Merge Logic"
## (descending traffic vs. traffic entering from an intermediate floor)
## would require linking adjacent connectors into one shared queue across
## floors, which the current per-floor node layout doesn't represent. As a
## practical approximation, arrival order at *this* connector already gives
## first-come-first-served priority, and the capacity cap below reproduces
## the "queue backs up under high density" behavior from 3.4.6.3.

@export var destination_floor: int = 0
@export var destination_marker_name: String = ""
@export var base_transit_time: float = 1.0   # T_transit in seconds, uncongested.
@export var capacity: int = 20               # Max agents physically on the stairs at once.
@export var is_blocked: bool = false         # "Constrained Scenario" (3.5).

var _queue: Array = []
var _in_transit_count: int = 0


func _ready() -> void:
	add_to_group("stairs")
	area_entered.connect(_on_area_entered)


## The StairConnector Area2D node itself always sits at local (0,0) under
## "StairConnectors" - the real-world location is entirely encoded in the
## child CollisionShape2D's position. Pathfinding targets must use this,
## not global_position directly.
func get_target_position() -> Vector2:
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			return child.global_position
	return global_position


func _on_area_entered(area: Area2D) -> void:
	if is_blocked:
		return

	var agent := area.get_parent()
	if agent == null or not agent.is_in_group("agents"):
		return
	if not agent.has_method("enter_stair_transit"):
		return
	if agent in _queue:
		return

	agent.enter_stair_transit()
	_queue.append(agent)
	_process_queue()


func _process_queue() -> void:
	while _in_transit_count < capacity and not _queue.is_empty():
		var agent = _queue.pop_front()
		_in_transit_count += 1
		_transit_agent(agent)


func _transit_agent(agent: Node) -> void:
	# Density-dependent slowdown of the stairwell, mirroring the Fundamental
	# Diagram of Pedestrian Flow used for in-corridor movement (3.4.6.3):
	# the fuller the stairwell, the longer the effective transit time.
	var rho: float = float(_in_transit_count)
	var rho_max: float = float(capacity)
	var slowdown: float = 1.0 / clamp(1.0 - (rho / (rho_max + 1.0)), 0.15, 1.0)
	var transit_time: float = base_transit_time * slowdown

	await get_tree().create_timer(transit_time).timeout

	_in_transit_count -= 1

	if is_instance_valid(agent):
		_complete_transit(agent)

	_process_queue()


func _complete_transit(agent: Node) -> void:
	var dest_floor = Manager.get_floor(destination_floor)
	if dest_floor == null:
		push_warning("StairConnector '%s': destination floor %d not registered with Manager." % [name, destination_floor])
		return

	var marker = dest_floor.get_wander_point_by_name(destination_marker_name)
	if marker == null:
		push_warning("StairConnector '%s': marker '%s' not found on floor %d." % [name, destination_marker_name, destination_floor])
		return

	agent.global_position = marker.global_position
	agent.exit_stair_transit(dest_floor)


func set_blocked(value: bool) -> void:
	is_blocked = value
