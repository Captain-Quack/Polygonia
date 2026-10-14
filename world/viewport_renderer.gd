@tool
extends Node2D
## Covers only the current viewport, in both the game and the 2D editor.
## Keep renderers at the World origin so their local coordinates are world units.

func _process(_delta: float) -> void:
	_sync_material()
	queue_redraw()

func _sync_material() -> void:
	pass

func _draw() -> void:
	var inverse := get_global_transform_with_canvas().affine_inverse()
	var size := get_viewport_rect().size
	var corners := PackedVector2Array([
		inverse * Vector2(-2, -2),
		inverse * Vector2(size.x + 2, -2),
		inverse * (size + Vector2(2, 2)),
		inverse * Vector2(-2, size.y + 2)
	])
	draw_colored_polygon(corners, Color.WHITE)
