@tool
extends "res://world/viewport_renderer.gd"

@export_group("Grid Geometry")
## Logical construction cell size. Zoom never changes this value.
@export_range(1.0, 1024.0, 1.0, "or_greater") var base_cell_size: float = 64.0
## Number of visible cells between major lines, independent of level multiplier.
@export_range(2, 32, 1) var major_step_count: int = 5
## Spacing multiplier between zoom-detail levels: 5 yields 1, 5, 25, 125 cells.
@export_range(2, 16, 1) var level_step_count: int = 5

@export_group("Line Appearance")
@export var minor_color: Color = Color(0.40, 0.55, 0.59, 0.24)
@export var major_color: Color = Color(0.35, 0.48, 0.52, 0.34)
@export_range(0.0, 1.0, 0.01) var grid_opacity: float = 1.0
## Thickness is in screen pixels, not world units.
@export_range(0.25, 5.0, 0.05) var minor_width: float = 0.75
@export_range(0.25, 8.0, 0.05) var major_width: float = 1.0

@export_group("Adaptive Detail")
## Minimum useful on-screen spacing before coarser levels take over.
@export_range(8.0, 128.0, 1.0) var target_screen_spacing: float = 24.0
## Fraction of each logarithmic zoom interval occupied by the transition.
@export_range(0.05, 1.0, 0.01) var fade_range: float = 1.0

func _ready() -> void:
	var shader_material := ShaderMaterial.new()
	shader_material.shader = preload("res://shaders/grid.gdshader")
	material = shader_material
	_sync_material()

func _sync_material() -> void:
	if material == null:
		return
	material.set_shader_parameter("base_cell_size", maxf(base_cell_size, 1.0))
	material.set_shader_parameter("major_step_count", maxi(major_step_count, 2))
	material.set_shader_parameter("level_step_count", maxi(level_step_count, 2))
	material.set_shader_parameter("minor_color", minor_color)
	material.set_shader_parameter("major_color", major_color)
	material.set_shader_parameter("grid_opacity", clampf(grid_opacity, 0.0, 1.0))
	material.set_shader_parameter("minor_width", maxf(minor_width, 0.25))
	material.set_shader_parameter("major_width", maxf(major_width, 0.25))
	material.set_shader_parameter("target_screen_spacing", maxf(target_screen_spacing, 8.0))
	material.set_shader_parameter("fade_range", clampf(fade_range, 0.05, 1.0))

func world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i((world_position / maxf(base_cell_size, 1.0)).floor())

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * maxf(base_cell_size, 1.0)
