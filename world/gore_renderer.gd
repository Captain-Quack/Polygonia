extends Node2D
## Ground presentation is deliberately below walls, agents, resources and overlays.
@onready var model: WorldModel = get_parent().get_node("WorldModel")
@onready var grid = get_parent().get_node("GridRenderer")
@onready var survival = get_parent().get_node("SurvivalView")
var _chip := PackedVector2Array([Vector2(-1,-.6),Vector2(1,-.35),Vector2(.2,1)])
var _last_time := -1.0
var _last_transform := Transform2D()
var _last_enabled := false
func _process(_delta: float) -> void:
	var at = maxf(0,model.simulation.gore.time-.1+survival.accumulator)
	var transform_now = get_canvas_transform()
	if at == _last_time and transform_now == _last_transform and _last_enabled == model.simulation.gore.enabled: return
	_last_time = at; _last_transform = transform_now; _last_enabled = model.simulation.gore.enabled
	queue_redraw()
func _draw() -> void:
	if not is_instance_valid(model) or not model.simulation.gore.enabled: return
	var effects: AgentGoreEffects = model.simulation.gore
	var cell: float = grid.base_cell_size
	var inverse = get_canvas_transform().affine_inverse()
	var screen = get_viewport_rect()
	var visible_rect = Rect2(inverse*screen.position,Vector2.ZERO)
	for corner in [Vector2(screen.end.x,screen.position.y),screen.end,Vector2(screen.position.x,screen.end.y)]: visible_rect = visible_rect.expand(inverse*corner)
	visible_rect = visible_rect.grow(cell)
	var at = maxf(0,effects.time-.1+survival.accumulator)
	var detailed = cell*get_canvas_transform().get_scale().x >= 14
	for mark in effects.stains:
		var point: Vector2 = mark.position*cell
		if not visible_rect.has_point(point): continue
		var age = maxf(0,at-mark.born)
		var dry = clampf(age/12,0,1)
		var fade = clampf((effects.STAIN_LIFE-age)/25,0,1)
		var color = Color(.52,.015,.025).lerp(Color(.25,.035,.04),dry)
		color.a = mark.opacity*fade*(1.0 if detailed else .55)
		# Small local shapes leave the grid readable and never cover silhouettes.
		draw_set_transform(point,mark.angle,Vector2.ONE*mark.radius*cell)
		draw_colored_polygon(mark.shape,color)
	draw_set_transform(Vector2.ZERO)
	if not detailed: return
	for p in effects.particles:
		var age = clampf(at-p.born,0,p.life)
		var point: Vector2 = (p.position+p.velocity*(1-exp(-3*age))/3.0)*cell
		point.y -= sin(age/p.life*PI)*.08*cell
		if not visible_rect.has_point(point): continue
		var color = Color(.7,.035,.04,.9)
		if p.chip:
			draw_set_transform(point,p.angle+age*4,Vector2.ONE*p.radius*cell)
			draw_colored_polygon(_chip,Color(.85,.59,.46,.95))
			draw_polyline(PackedVector2Array([_chip[0],_chip[1],_chip[2],_chip[0]]),Color(.45,.025,.035),.3)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_line(point,point-p.velocity.normalized()*.05*cell,color,maxf(1,p.radius*cell*2),true)
