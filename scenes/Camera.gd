extends Camera2D

var dragging: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO

@export var zoom_speed: float = 0.05
@export var min_zoom: float = 0.05
@export var max_zoom: float = 3.0
@export var pan_speed: float = 1.0

func _ready() -> void:
	make_current()

func _process(_delta: float) -> void:
	# Zoom with scroll wheel - checked every frame
	if Input.is_action_just_pressed("ui_scroll_up"):
		zoom.x = clamp(zoom.x + zoom_speed, min_zoom, max_zoom)
		zoom.y = zoom.x

	if Input.is_action_just_pressed("ui_scroll_down"):
		zoom.x = clamp(zoom.x - zoom_speed, min_zoom, max_zoom)
		zoom.y = zoom.x

func _unhandled_input(event: InputEvent) -> void:
	# Pan with left click drag
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			last_mouse_pos = event.position

		# Fallback scroll in case ui_scroll actions aren't set
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom.x = clamp(zoom.x + zoom_speed, min_zoom, max_zoom)
			zoom.y = zoom.x
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom.x = clamp(zoom.x - zoom_speed, min_zoom, max_zoom)
			zoom.y = zoom.x

	if event is InputEventMouseMotion and dragging:
		var delta = event.position - last_mouse_pos
		position -= delta / zoom.x
		last_mouse_pos = event.position
