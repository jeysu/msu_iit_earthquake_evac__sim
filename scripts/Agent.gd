extends CharacterBody2D

# --- Attributes (randomized per agent) ---
var walk_speed: float
var run_speed: float
var reaction_time: float
var state: String = "NORMAL"
var target_position: Vector2 = Vector2.ZERO
var assigned_floor: int = 0  # which floor this agent is on

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Randomize individual attributes for realism
	walk_speed = randf_range(60.0, 100.0)
	run_speed  = randf_range(150.0, 220.0)
	reaction_time = randf_range(0.5, 3.0)

	# Listen for the earthquake signal from Manager
	Manager.earthquake_started.connect(_on_earthquake_triggered)

	# Start wandering
	_pick_random_wander_target()

func _physics_process(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		if state == "NORMAL":
			_pick_random_wander_target()
		return

	var next_pos: Vector2 = nav_agent.get_next_path_position()
	var direction: Vector2 = (next_pos - global_position).normalized()

	# Density-dependent speed (Fundamental Diagram of Pedestrian Flow)
	var local_density: float = Manager.get_local_density(global_position)
	var density_max: float   = Manager.density_max
	var speed_factor: float  = clamp(1.0 - (local_density / density_max), 0.05, 1.0)

	var current_speed: float = (walk_speed if state == "NORMAL" else run_speed) * speed_factor
	velocity = direction * current_speed
	move_and_slide()

	# Color feedback: green = normal, red = panic
	sprite.modulate = Color.GREEN if state == "NORMAL" else Color.RED

func _pick_random_wander_target() -> void:
	# Wander to a random point within the floor's nav region
	var floor_node = get_parent()  # Floor node holds wander points
	if floor_node.has_method("get_random_wander_point"):
		target_position = floor_node.get_random_wander_point()
		nav_agent.target_position = target_position

func _on_earthquake_triggered() -> void:
	# Delayed reaction based on individual reaction_time
	await get_tree().create_timer(reaction_time).timeout
	state = "PANIC"
	sprite.modulate = Color.RED
	_navigate_to_nearest_exit()

func _navigate_to_nearest_exit() -> void:
	var nearest_exit: Node2D = Manager.get_nearest_exit(global_position, assigned_floor)
	if nearest_exit:
		nav_agent.target_position = nearest_exit.global_position
