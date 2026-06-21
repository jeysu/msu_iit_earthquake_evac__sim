extends Node
## Manager.gd - Central simulation director / data analysis layer.
##
## SETUP (required): This script must be added as an AUTOLOAD singleton.
##   Project > Project Settings > Autoload
##   Path: res://scripts/Manager.gd   Node Name: Manager
## It is not attached to any node in Main.tscn on purpose - everything else
## (Agent, Exit, StairConnector, Floor, UI) talks to it as "Manager.xxx".
##
## Thesis ref: Chapter 3.4.4 "The Manager (Data Analysis Layer)", Listing 3.3,
## and Chapter 3.6 "Data Analysis".

signal earthquake_started
signal agent_escaped_updated(escaped_count: int, total_count: int)
signal simulation_started(scenario_name: String)
signal simulation_complete(stats: Dictionary)

enum Scenario { BASELINE, HIGH_DENSITY, CONSTRAINED }

# --- Scenario configuration (3.5 Simulation Scenarios) ---

# Multiplies each floor's base_occupancy to model peak-hour / time-of-day load.
var occupancy_multiplier: Dictionary = {
	Scenario.BASELINE: 1.0,
	Scenario.HIGH_DENSITY: 1.8,
	Scenario.CONSTRAINED: 1.0,
}

# Node names of Exit / StairConnector instances to disable for the
# "Constrained Scenario" (partial structural failure, 3.5). Fill these in
# with real node names (e.g. "Stair_0_2") once you've identified which
# routes you want to stress-test.
var blocked_exit_names: Dictionary = {
	Scenario.CONSTRAINED: [],
}
var blocked_stair_names: Dictionary = {
	Scenario.CONSTRAINED: [],
}

var time_to_earthquake: float = 5.0  # Seconds of "Normal" wandering before the quake signal fires.

# Fraction of total_agents_spawned that must escape before the simulation
# is considered complete (the long tail of stragglers is treated as noise
# once the bulk of the crowd is out).
var evacuation_completion_threshold: float = 0.9

# --- Runtime state ---
var current_scenario: int = Scenario.BASELINE
var simulation_running: bool = false
var earthquake_triggered: bool = false
var elapsed_time: float = 0.0

var floors: Dictionary = {}     # floor_index (int) -> Floor node
var agents: Array = []          # all currently-active Agent nodes

var total_agents_spawned: int = 0
var agents_escaped: int = 0
var escape_log: Array = []      # [{agent_id, time, floor}, ...]

# --- Heat map density grid (3.6 Data Analysis / "Red Zones") ---
var cell_size: float = 32.0
var live_density: Dictionary = {}   # Vector2i cell -> float (decaying live count)
var density_decay: float = 0.92


# ---------------------------------------------------------------------------
# Registration (called by Floor.gd and Agent.gd)
# ---------------------------------------------------------------------------

func register_floor(floor_index: int, floor_node: Node) -> void:
	floors[floor_index] = floor_node


func get_floor(floor_index: int) -> Node:
	return floors.get(floor_index, null)


func register_agent(agent: Node) -> void:
	agents.append(agent)
	total_agents_spawned += 1


func agent_escaped(agent: Node) -> void:
	if not simulation_running:
		return  # Already wrapped up (e.g. a same-frame straggler reaching an exit
				# right as the 90% threshold was hit) - don't double-count or re-finish.

	agents_escaped += 1
	var floor_idx: int = agent.current_floor.floor_index if agent.current_floor else -1
	escape_log.append({"agent_id": agent.get_instance_id(), "time": elapsed_time, "floor": floor_idx})
	agents.erase(agent)
	agent_escaped_updated.emit(agents_escaped, total_agents_spawned)

	if agents_escaped >= _required_escapes_for_completion():
		_finish_simulation()


func _required_escapes_for_completion() -> int:
	# At least 1 agent, and rounded up so e.g. 10 agents @ 90% requires 9, not 8.
	return int(max(1, ceil(total_agents_spawned * evacuation_completion_threshold)))


# ---------------------------------------------------------------------------
# Density tracking (used by Agent.gd for crowd slowdown, and HeatMap.gd)
# ---------------------------------------------------------------------------

func log_position(world_pos: Vector2) -> void:
	var cell := Vector2i(int(floor(world_pos.x / cell_size)), int(floor(world_pos.y / cell_size)))
	live_density[cell] = live_density.get(cell, 0.0) + 1.0


func get_local_agent_count(world_pos: Vector2, radius: float, exclude: Node = null) -> int:
	var count := 0
	for a in agents:
		if a == exclude or not is_instance_valid(a):
			continue
		if a.global_position.distance_to(world_pos) <= radius:
			count += 1
	return count


# ---------------------------------------------------------------------------
# Simulation control
# ---------------------------------------------------------------------------

func start_simulation(scenario: int = Scenario.BASELINE) -> void:
	current_scenario = scenario
	simulation_running = true
	earthquake_triggered = false
	elapsed_time = 0.0
	agents_escaped = 0
	total_agents_spawned = 0
	escape_log.clear()
	agents.clear()
	live_density.clear()

	_apply_scenario_blocks(scenario)
	_spawn_all_agents(scenario)

	simulation_started.emit(Scenario.keys()[scenario])


func _apply_scenario_blocks(scenario: int) -> void:
	var blocked_exits: Array = blocked_exit_names.get(scenario, [])
	for exit_node in get_tree().get_nodes_in_group("exits"):
		if exit_node.has_method("set_blocked"):
			exit_node.set_blocked(exit_node.name in blocked_exits)

	var blocked_stairs: Array = blocked_stair_names.get(scenario, [])
	for stair_node in get_tree().get_nodes_in_group("stairs"):
		if stair_node.has_method("set_blocked"):
			stair_node.set_blocked(stair_node.name in blocked_stairs)


func _spawn_all_agents(scenario: int) -> void:
	var mult: float = occupancy_multiplier.get(scenario, 1.0)
	for idx in floors.keys():
		var f = floors[idx]
		var count: int = int(round(f.base_occupancy * mult))
		f.spawn_agents(count)


func _process(delta: float) -> void:
	if not simulation_running:
		return

	elapsed_time += delta

	# Decay the live density grid so the heat map reflects *current* congestion.
	for k in live_density.keys():
		live_density[k] *= density_decay
		if live_density[k] < 0.05:
			live_density.erase(k)


func trigger_earthquake() -> void:
	if not earthquake_triggered:
		earthquake_triggered = true
		earthquake_started.emit()


func _finish_simulation() -> void:
	simulation_running = false
	var stats := {
		"scenario": Scenario.keys()[current_scenario],
		"total_evacuation_time": elapsed_time,
		"total_agents": total_agents_spawned,
		"escaped": agents_escaped,
		"evacuated_percentage": (float(agents_escaped) / float(total_agents_spawned)) * 100.0 if total_agents_spawned > 0 else 0.0,
	}
	_retire_remaining_agents()
	_export_logs_to_csv()
	simulation_complete.emit(stats)


## Anyone still mid-evacuation once the completion threshold is hit is outside
## the scope of this run. Stop them in place and free them so they can't keep
## moving in the background, escape late, and corrupt the *next* run's count.
func _retire_remaining_agents() -> void:
	for a in agents.duplicate():
		if not is_instance_valid(a):
			continue
		if a.has_method("set_physics_process"):
			a.set_physics_process(false)
		var detection: Node = a.get_node_or_null("Area2D")
		if detection:
			detection.set_deferred("monitoring", false)
			detection.set_deferred("monitorable", false)
		a.queue_free()
	agents.clear()


func _export_logs_to_csv() -> void:
	var dir_path := "user://logs"
	DirAccess.make_dir_recursive_absolute(dir_path)

	var file_path := "%s/evac_log_%d.csv" % [dir_path, Time.get_unix_time_from_system()]
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_warning("Manager: could not open log file for writing: %s" % file_path)
		return

	file.store_line("agent_id,time_seconds,floor")
	for entry in escape_log:
		file.store_line("%s,%s,%s" % [entry.agent_id, entry.time, entry.floor])
	file.close()

	print("Manager: evacuation log exported to ", file_path)
