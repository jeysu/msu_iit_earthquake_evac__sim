extends CanvasLayer

@onready var label_timer   = $Label_Timer
@onready var label_escaped = $Label_Escaped
@onready var label_scenario = $Label_Scenario
@onready var btn_start     = $Button_Start

func _ready() -> void:
	btn_start.pressed.connect(_on_start_pressed)
	_update_scenario_label()

func _on_start_pressed() -> void:
	Manager.trigger_earthquake()
	btn_start.disabled = true

func _process(_delta: float) -> void:
	label_escaped.text = "Escaped: %d / %d" % [Manager.agents_escaped, Manager.total_agents]

	if Manager.earthquake_active:
		var elapsed = (Time.get_ticks_msec() - Manager.quake_time) / 1000.0
		label_timer.text = "Evacuation Time: %.1fs" % elapsed
	else:
		var pre = (Time.get_ticks_msec() - Manager.sim_start_time) / 1000.0
		label_timer.text = "Pre-quake: %.1fs" % pre

func _update_scenario_label() -> void:
	var names = ["Baseline", "High Density", "Constrained"]
	label_scenario.text = "Scenario: " + names[Manager.current_scenario]
