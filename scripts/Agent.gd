extends CharacterBody2D

var walk_speed: float
var run_speed: float
var reaction_time: float
var state: String = "NORMAL"
var target_position: Vector2 = Vector2.ZERO
var assigned_floor: int = 0

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	walk_speed    = randf_range(60.0, 100.0)
	run_speed     = randf_range(150.0, 220.0)
	reaction_time = randf_range(0.5, 3.0)
	Manager.earthquake_started.connect(_on_earthquake_triggered)
	
	nav_agent.target_position = global_position
	
	await get_tree().physics_frame
	await get_tree().physics_frame
	_pick_random_wander_target()

func _physics_process(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		if state == "NORMAL":
			_pick_random_wander_target()
		elif state == "PANIC":
			_navigate_to_nearest_exit()
		return

	var next_pos: Vector2 = nav_agent.get_next_path_position()
	var direction: Vector2 = (next_pos - global_position).normalized()

	var local_density: float = Manager.get_local_density(global_position)
	var density_max: float   = Manager.density_max
	var speed_factor: float  = clamp(1.0 - (local_density / density_max), 0.05, 1.0)

	var current_speed: float = (walk_speed if state == "NORMAL" else run_speed) * speed_factor
	velocity = direction * current_speed
	move_and_slide()

	sprite.modulate = Color.GREEN if state == "NORMAL" else Color.RED

func _pick_random_wander_target() -> void:
	var floor_node = Manager.floors.get(assigned_floor)
	if floor_node and floor_node.has_method("get_random_wander_point"):
		target_position = floor_node.get_random_wander_point()
		nav_agent.target_position = target_position
	else:
		push_warning("Agent %d: Floor %d not found in Manager!" % [get_instance_id(), assigned_floor])
		
func _on_earthquake_triggered() -> void:
	await get_tree().create_timer(reaction_time).timeout
	state = "PANIC"
	sprite.modulate = Color.RED
	nav_agent.target_position = global_position
	_check_exit_overlap()
	_navigate_to_nearest_exit()

func _check_exit_overlap() -> void:
	for exit in Manager.exits:
		if exit.has_method("despawn_panic_agents"):
			exit.despawn_panic_agents()

func _navigate_to_nearest_exit() -> void:
	var nearest_exit: Node2D = Manager.get_nearest_exit(global_position, assigned_floor)
	if nearest_exit:
		nav_agent.target_position = Manager.get_area_position(nearest_exit)
		return

	var nearest_stair: Node2D = Manager.get_nearest_stair(global_position, assigned_floor)
	if nearest_stair:
		nav_agent.target_position = Manager.get_area_position(nearest_stair)
		return
	
	push_warning("Agent %d on floor %d: No exit or stair found!" % [get_instance_id(), assigned_floor])
