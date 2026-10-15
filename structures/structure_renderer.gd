extends Node2D
@export var wall_color:=Color(.24,.28,.27,1)
@export var door_color:=Color(.28,.46,.42,1)
@export var locked_color:=Color(.65,.29,.23,1)
var ink: CanvasGroup
@onready var model: WorldModel=get_parent().get_node("WorldModel")
@onready var grid=get_parent().get_node("GridRenderer")
var _revision:=-1
var _cell_size:=-1.0
func _ready() -> void:
	ink=preload("res://floors/rounded_ink.gd").new();add_child(ink)
func _process(_delta: float) -> void:
	if _revision==model.structures.revision and _cell_size==grid.base_cell_size:return
	_revision=model.structures.revision;_cell_size=grid.base_cell_size
	var paths: Array=[]
	for segment in model.physical.segments():
		if not segment.door:paths.append(PackedVector2Array([segment.a*_cell_size,segment.b*_cell_size]))
	ink.configure(paths,.1*_cell_size,wall_color)
	queue_redraw()
func _draw() -> void:
	if not is_instance_valid(model):return
	var cell: float=grid.base_cell_size
	for door in model.structures.get_doors():
		var a=Vector2(door.a)*cell;var b=Vector2(door.b)*cell
		var color=locked_color if door.locked else door_color
		if door.state==&"CLOSED":
			draw_line(a,b,color,.1*cell,true);draw_circle(a,.05*cell,color);draw_circle(b,.05*cell,color)
		else:
			var direction=(b-a).normalized();var normal=Vector2(-direction.y,direction.x)
			# Thin swing illustration has no collision; the aperture itself is clear.
			draw_line(a,a+normal*(b-a).length(),color,.025*cell,true)
			draw_arc(a,(b-a).length(),direction.angle(),normal.angle() if normal.angle()>direction.angle() else normal.angle()+TAU,16,Color(color,.45),.015*cell,true)
		if door.locked:
			var p=(a+b)*.5
			draw_circle(p,.12*cell,color,false,.025*cell,true)
