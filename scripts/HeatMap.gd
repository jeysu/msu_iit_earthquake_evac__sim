extends Node2D

var cell_size: float = 40.0
var max_density: int = 8        # fully red at this count
var enabled: bool    = true

func _process(_delta: float) -> void:
	queue_redraw()   # trigger _draw every frame

func _draw() -> void:
	if not enabled:
		return
	for cell_vec in Manager.density_grid:
		var count: int = Manager.density_grid[cell_vec]
		if count == 0:
			continue
		var t: float   = clamp(float(count) / float(max_density), 0.0, 1.0)
		# Interpolate green → yellow → red
		var col: Color = Color(t, 1.0 - t, 0.0, 0.35)
		var rect = Rect2(
			Vector2(cell_vec.x * cell_size, cell_vec.y * cell_size),
			Vector2(cell_size, cell_size)
		)
		draw_rect(rect, col)
