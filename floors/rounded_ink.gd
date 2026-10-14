@tool
extends CanvasGroup
## Render overlapping strokes as opaque ink, then apply color/opacity once.
## This keeps round caps, T junctions, and crosses from accumulating opacity.
const Geometry = preload("res://floors/shape_geometry.gd")
var paths: Array = []
var width := 1.0
var closed := false
var painter: Node2D

func _ready() -> void:
	painter = Node2D.new()
	painter.name = "Ink"
	add_child(painter)
	painter.draw.connect(_paint)

func configure(new_paths: Array, new_width: float, color: Color, close_paths: bool = false) -> void:
	paths = new_paths
	width = new_width
	closed = close_paths
	self_modulate = color
	if is_instance_valid(painter):
		painter.queue_redraw()

func _paint() -> void:
	for path in paths:
		Geometry.round_stroke(painter, path, Color.WHITE, width, closed)
