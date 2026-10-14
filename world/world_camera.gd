extends Camera2D
## Camera navigation is disabled in the editor, which supplies its own canvas transform.

@export_group("Zoom")
@export_range(0.0001, 1.0, 0.0001) var minimum_zoom: float = 0.002
@export_range(1.0, 64.0, 0.1) var maximum_zoom: float = 8.0
@export_range(0.001, 32.0, 0.001) var initial_zoom: float = 1.0
@export_range(0.01, 1.0, 0.01) var wheel_zoom_step: float = 0.15
## Exponential smoothing rate; zero applies wheel zoom immediately.
@export_range(0.0, 40.0, 0.5) var zoom_smoothing: float = 18.0

@export_group("Pan and Home")
@export var home_position: Vector2 = Vector2.ZERO
@export_range(0.1, 4.0, 0.05) var pan_sensitivity: float = 1.0
@export var middle_drag_enabled: bool = true
@export var space_drag_enabled: bool = true
@export var reset_key: Key = KEY_HOME

var construction_active := false

var _target_zoom: float = 1.0
var _anchor: Vector2 = Vector2.ZERO
var _drag_button: int = 0

func _ready() -> void:
	position_smoothing_enabled = false
	reset_view()

func _bounded_zoom(value: float) -> float:
	var low := maxf(minf(minimum_zoom, maximum_zoom), 0.0001)
	var high := maxf(maxf(minimum_zoom, maximum_zoom), low)
	return clampf(value, low, high)

func reset_view() -> void:
	position = home_position
	_target_zoom = _bounded_zoom(initial_zoom)
	zoom = Vector2.ONE * _target_zoom
	_drag_button = 0
	force_update_scroll()

## Immediate operation, also used for each smooth-zoom frame.
func zoom_about(screen_position: Vector2, new_zoom: float) -> void:
	force_update_scroll()
	var before := get_canvas_transform().affine_inverse() * screen_position
	zoom = Vector2.ONE * _bounded_zoom(new_zoom)
	force_update_scroll()
	var after := get_canvas_transform().affine_inverse() * screen_position
	global_position += before - after
	force_update_scroll()

func _process(delta: float) -> void:
	_target_zoom = _bounded_zoom(_target_zoom)
	if not is_equal_approx(zoom.x, _target_zoom):
		var next_zoom := _target_zoom
		if zoom_smoothing > 0.0:
			next_zoom = exp(lerpf(log(zoom.x), log(_target_zoom), 1.0 - exp(-zoom_smoothing * delta)))
		zoom_about(_anchor, next_zoom)

func _input(event: InputEvent) -> void:
	# Releases must arrive even when the pointer is now over a UI control.
	if event is InputEventMouseButton and not event.pressed and event.button_index == _drag_button:
		_drag_button = 0
	if event is InputEventKey and event.keycode == KEY_SPACE and not event.pressed and _drag_button == MOUSE_BUTTON_LEFT:
		_drag_button = 0

func _unhandled_input(event: InputEvent) -> void:
	if construction_active:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == reset_key:
		reset_view()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_anchor = event.position
			var direction := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
			_target_zoom = _bounded_zoom(_target_zoom * exp(direction * wheel_zoom_step * event.factor))
			if zoom_smoothing <= 0.0:
				zoom_about(_anchor, _target_zoom)
			get_viewport().set_input_as_handled()
		elif (middle_drag_enabled and event.button_index == MOUSE_BUTTON_MIDDLE) or (space_drag_enabled and event.button_index == MOUSE_BUTTON_LEFT and Input.is_physical_key_pressed(KEY_SPACE)):
			_drag_button = event.button_index
			_target_zoom = zoom.x
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _drag_button != 0:
		position -= event.relative / zoom * pan_sensitivity
		force_update_scroll()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_drag_button = 0
