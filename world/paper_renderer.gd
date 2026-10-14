@tool
extends "res://world/viewport_renderer.gd"

@export_group("Paper")
@export var paper_color: Color = Color("f6f1e7")
@export var grain_color: Color = Color("817461")
@export_range(0.0, 0.3, 0.001) var grain_strength: float = 0.035
## World units per grain feature. Grain stays attached to the paper.
@export_range(0.1, 32.0, 0.1) var grain_scale: float = 1.6
@export_range(0, 10000, 1) var grain_seed: int = 27

func _ready() -> void:
	var shader_material := ShaderMaterial.new()
	shader_material.shader = preload("res://shaders/paper.gdshader")
	material = shader_material
	_sync_material()

func _sync_material() -> void:
	if material == null:
		return
	material.set_shader_parameter("paper_color", paper_color)
	material.set_shader_parameter("grain_color", grain_color)
	material.set_shader_parameter("grain_strength", clampf(grain_strength, 0.0, 0.3))
	material.set_shader_parameter("grain_scale", maxf(grain_scale, 0.1))
	material.set_shader_parameter("grain_seed", float(grain_seed))
