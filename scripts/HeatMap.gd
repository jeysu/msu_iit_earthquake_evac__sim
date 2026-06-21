extends Node2D
## HeatMap.gd - Visualizes live crowd density as a heat map overlay.
## Attach to: "HeatMapCanvas" Node2D in Main.tscn.
##
## Reads Manager.live_density (a decaying Vector2i-cell -> count grid that
## every Agent feeds into via Manager.log_position() each physics frame).
##
## Thesis ref: Chapter 3.6 "Data Analysis" - heat maps highlighting
## congestion "Red Zones".

@export var enabled: bool = true
@export var max_intensity: float = 50.0  # Density value that maps to fully red.


func _process(_delta: float) -> void:
	if enabled:
		queue_redraw()


func _draw() -> void:
	if not enabled:
		return

	for cell in Manager.live_density.keys():
		var value: float = Manager.live_density[cell]
		if value < 5.0:
			continue

		var t: float = clamp(value / max_intensity, 0.0, 1.0)
		var color := _heat_color(t)
		var rect_pos := Vector2(cell.x, cell.y) * Manager.cell_size
		draw_rect(Rect2(rect_pos, Vector2(Manager.cell_size, Manager.cell_size)), color)


func _heat_color(t: float) -> Color:
	# Green (low) -> Yellow (medium) -> Red (high congestion / "Red Zone").
	var c: Color
	if t < 0.5:
		c = Color(0, 1, 0).lerp(Color(1, 1, 0), t * 2.0)
	else:
		c = Color(1, 1, 0).lerp(Color(1, 0, 0), (t - 0.5) * 2.0)
	c.a = 0.15 + t * 0.5
	return c


func toggle() -> void:
	enabled = not enabled
	if not enabled:
		queue_redraw()
