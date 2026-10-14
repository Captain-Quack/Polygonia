@tool
extends Node2D
const RoundedInk = preload("res://floors/rounded_ink.gd")
const Geometry = preload("res://floors/shape_geometry.gd")

@export_group("Floor")
@export var fill_color := Color(0.48, 0.58, 0.53, 0.30)
@export var ink_color := Color("53675b")
@export_range(0.5, 16.0, 0.1) var ink_width := 3.5
@export_range(0.0, 32.0, 0.5) var corner_radius := 10.0
@export_group("Lines")
@export var line_color := Color("394e42")
@export_range(0.5, 24.0, 0.1) var line_width := 5.0
@export_group("Pencil Texture")
@export_range(0.0, 3.0, 0.1) var hand_drawn_amount := 0.7
@export_range(0.0, 1.0, 0.05) var pencil_opacity := 0.16
@export_range(0.2, 6.0, 0.1) var pencil_width := 1.0

var data: RefCounted:
	set(value):
		if data != null and data.changed.is_connected(_invalidate):
			data.changed.disconnect(_invalidate)
		data = value
		if data != null:
			data.changed.connect(_invalidate)
		_invalidate()
var grid: Node2D
var _dirty := true
var _loops: Array = []
var _rounded: Array = []
var _bands: Array[PackedVector2Array] = []
var _cache_key := Vector3(-1, -1, -1)

var _outline_ink: CanvasGroup
var _line_ink: CanvasGroup

func _ready() -> void:
	_outline_ink = RoundedInk.new()
	_outline_ink.name = "FloorInk"
	add_child(_outline_ink)
	_line_ink = RoundedInk.new()
	_line_ink.name = "LineInk"
	add_child(_line_ink)

func _invalidate() -> void:
	_dirty = true
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if data == null or grid == null:
		return
	var zoom_scale := maxf(get_global_transform_with_canvas().get_scale().x, 0.0001)
	var cell_size: float = grid.base_cell_size
	var key := Vector3(zoom_scale, cell_size, corner_radius)
	if _dirty:
		_loops = data.boundary_loops()
	if _dirty or key != _cache_key:
		_rounded.clear()
		for loop in _loops:
			var points := PackedVector2Array()
			for point in loop:
				points.append(Vector2(point) * cell_size)
			_rounded.append(Geometry.rounded_loop(points, minf(corner_radius / zoom_scale, cell_size * 0.45)))
		_bands = Geometry.fill_bands(_rounded)
		_cache_key = key
		_dirty = false
	for band in _bands:
		draw_colored_polygon(band, fill_color)
	_outline_ink.configure(_rounded, ink_width / zoom_scale, ink_color, true)
	for loop in _rounded:
		if hand_drawn_amount > 0 and pencil_opacity > 0:
			var pencil: PackedVector2Array = loop.duplicate()
			for i in range(pencil.size()):
				pencil[i] += Vector2(sin(float(i) * 2.3), cos(float(i) * 1.7)) * hand_drawn_amount / zoom_scale
			pencil.append(pencil[0])
			draw_polyline(pencil, Color(ink_color, ink_color.a * pencil_opacity), pencil_width / zoom_scale, true)
	var line_paths: Array = []
	for line in data.lines:
		var points := PackedVector2Array([Vector2(line.x, line.y) * cell_size, Vector2(line.z, line.w) * cell_size])
		line_paths.append(points)
	_line_ink.configure(line_paths, line_width / zoom_scale, line_color)
