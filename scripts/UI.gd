extends CanvasLayer
## UI.gd - Heads-up display: timer, escaped count, scenario, start button.
## Attach to: "CanvasLayer" node under "UI" in Main.tscn.
## Children expected (already present in Main.tscn): Label_Timer,
## Label_Escaped, Label_Scenario, Button_Start.

@onready var label_timer: Label = $Label_Timer
@onready var label_escaped: Label = $Label_Escaped
@onready var label_scenario: Label = $Label_Scenario
@onready var button_start: Button = $Button_Start
@onready var button_panic: Button = $Button_Panic

var _current_scenario: int = Manager.Scenario.BASELINE


func _ready() -> void:
	button_start.pressed.connect(_on_button_start_pressed)
	button_panic.pressed.connect(_on_button_panic_pressed)

	# Labels ignore mouse input by default; enable it so clicking cycles scenarios.
	label_scenario.mouse_filter = Control.MOUSE_FILTER_STOP
	label_scenario.gui_input.connect(_on_scenario_label_input)

	Manager.earthquake_started.connect(_on_earthquake_started)
	Manager.agent_escaped_updated.connect(_on_agent_escaped_updated)
	Manager.simulation_complete.connect(_on_simulation_complete)

	_refresh_scenario_label()
	label_escaped.text = "Escaped: 0 / 0"
	label_timer.text = "Time: 0.0s"


func _process(_delta: float) -> void:
	if Manager.simulation_running:
		label_timer.text = "Time: %.1fs" % Manager.elapsed_time


func _on_button_start_pressed() -> void:
	if Manager.simulation_running:
		return
	button_start.disabled = true
	button_start.text = "Running..."
	button_panic.disabled = false
	label_escaped.text = "Escaped: 0 / 0"
	label_scenario.modulate = Color(1, 1, 1)
	Manager.start_simulation(_current_scenario)


func _on_button_panic_pressed() -> void:
	if Manager.simulation_running and not Manager.earthquake_triggered:
		Manager.trigger_earthquake()
		button_panic.disabled = true


func _on_scenario_label_input(event: InputEvent) -> void:
	if Manager.simulation_running:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_current_scenario = (_current_scenario + 1) % Manager.Scenario.size()
		_refresh_scenario_label()


func _refresh_scenario_label() -> void:
	label_scenario.text = "Scenario: %s (click to change)" % Manager.Scenario.keys()[_current_scenario]


func _on_earthquake_started() -> void:
	label_scenario.modulate = Color(1, 0.3, 0.3)


func _on_agent_escaped_updated(count: int, total: int) -> void:
	label_escaped.text = "Escaped: %d / %d" % [count, total]


func _on_simulation_complete(stats: Dictionary) -> void:
	label_timer.text = "Done in %.1fs (%.0f%% evacuated)" % [stats.get("total_evacuation_time", 0.0), stats.get("evacuated_percentage", 0.0)]
	button_start.disabled = false
	button_start.text = "Restart"
	button_panic.disabled = true
