extends Node

# ── Signals ──────────────────────────────────────────────────────────────────
signal earthquake_started

# ── Scenario config ───────────────────────────────────────────────────────────
enum Scenario { BASELINE, HIGH_DENSITY, CONSTRAINED }
@export var current_scenario: Scenario = Scenario.BASELINE

# ── Simulation state ──────────────────────────────────────────────────────────
var total_agents:    int   = 0
var agents_escaped:  int   = 0
var earthquake_active: bool = false
var sim_start_time:  int   = 0   # msec
var quake_time:      int   = 0   # msec when quake fired

# ── Density tracking ─────────────────────────────────────────────────────────
var density_max: float         = 6.0   # agents per m² (stand-still)
var density_cell_size: float   = 40.0  # px per cell for density grid
var density_grid: Dictionary   = {}    # Vector2i → int count

# ── Floor & exit registry ────────────────────────────────────────────────────
var floors: Dictionary = {}   # floor_index → Floor node
var exits:  Array      = []   # all Area2D exit nodes (all floors)

# ── CSV log ───────────────────────────────────────────────────────────────────
var escape_log: Array = []  # [{agent_id, escape_time_ms}]

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Slight delay so floors can register themselves first
	await get_tree().process_frame
	await get_tree().process_frame
	_apply_scenario()
	_spawn_all_agents()

func register_floor(index: int, floor_node: Node2D) -> void:
	floors[index] = floor_node
	# Collect exits from this floor
	for exit in floor_node.get_node("Exits").get_children():
		exits.append(exit)

# ── Scenario logic ────────────────────────────────────────────────────────────
func _apply_scenario() -> void:
	match current_scenario:
		Scenario.BASELINE:
			for idx in floors:
				floors[idx].occupancy = 50   # normal class hours
		Scenario.HIGH_DENSITY:
			for idx in floors:
				floors[idx].occupancy = 120  # peak / dismissal
		Scenario.CONSTRAINED:
			for idx in floors:
				floors[idx].occupancy = 50
			# Disable first exit on each floor to simulate blocked exit
			_block_exits()

func _block_exits() -> void:
	for floor_node in floors.values():
		var floor_exits = floor_node.get_node("Exits").get_children()
		if floor_exits.size() > 0:
			floor_exits[0].monitoring = false  # block first exit
			floor_exits[0].modulate   = Color.RED

# ── Spawning ──────────────────────────────────────────────────────────────────
func _spawn_all_agents() -> void:
	total_agents = 0
	for idx in floors:
		floors[idx].spawn_agents()
		total_agents += floors[idx].occupancy
	sim_start_time = Time.get_ticks_msec()

# ── Earthquake trigger (call from UI button or timer) ────────────────────────
func trigger_earthquake() -> void:
	if earthquake_active:
		return
	earthquake_active = true
	quake_time        = Time.get_ticks_msec()
	earthquake_started.emit()
	print("🔴 EARTHQUAKE TRIGGERED at t=%.2fs" % ((quake_time - sim_start_time) / 1000.0))

# ── Agent escaped callback ────────────────────────────────────────────────────
func agent_escaped(agent: Node2D) -> void:
	agents_escaped += 1
	var t = Time.get_ticks_msec()
	escape_log.append({
		"agent_id":      agent.get_instance_id(),
		"escape_time_ms": t - quake_time
	})
	agent.queue_free()

	if agents_escaped >= total_agents:
		_on_all_escaped()

func _on_all_escaped() -> void:
	var total_ms  = Time.get_ticks_msec() - quake_time
	var total_sec = total_ms / 1000.0
	print("✅ All agents escaped! Total evacuation time: %.2f seconds" % total_sec)
	_export_csv()

# ── Nearest-exit helper ───────────────────────────────────────────────────────
func get_nearest_exit(pos: Vector2, floor_idx: int) -> Node2D:
	var best: Node2D  = null
	var best_dist: float = INF
	if floors.has(floor_idx):
		var floor_exits = floors[floor_idx].get_node("Exits").get_children()
		for ex in floor_exits:
			if not ex.monitoring:
				continue  # skip blocked exits
			var d = pos.distance_to(ex.global_position)
			if d < best_dist:
				best_dist = d
				best = ex
	return best

# ── Density grid ──────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	_rebuild_density_grid()

func _rebuild_density_grid() -> void:
	density_grid.clear()
	for floor_node in floors.values():
		for agent in floor_node.get_node("Agents").get_children():
			var cell = Vector2i(
				int(agent.global_position.x / density_cell_size),
				int(agent.global_position.y / density_cell_size)
			)
			density_grid[cell] = density_grid.get(cell, 0) + 1

func get_local_density(pos: Vector2) -> float:
	var cell = Vector2i(int(pos.x / density_cell_size), int(pos.y / density_cell_size))
	var count = density_grid.get(cell, 0)
	# Convert agent count to density (agents per m², assuming 1 cell = 1 m²)
	return float(count)

# ── CSV export ────────────────────────────────────────────────────────────────
func _export_csv() -> void:
	var path = "user://evacuation_log.csv"
	var f    = FileAccess.open(path, FileAccess.WRITE)
	f.store_line("agent_id,escape_time_ms,escape_time_s")
	for entry in escape_log:
		f.store_line("%d,%d,%.3f" % [
			entry["agent_id"],
			entry["escape_time_ms"],
			entry["escape_time_ms"] / 1000.0
		])
	f.close()
	print("📄 CSV saved to: " + path)
