## Keeps track of a parent RayCast2D node and draws a line based on it.
##
## The color changes when the parent is colliding.
@tool
class_name DebugDrawRayCast2D extends Node2D

const BASE_COLOR := Color(0.301961, 0.65098, 1)
const PLAYER_COLLISION_COLOR := Color(0.560784, 0.870588, 0.364706)
const WALL_COLLISION_COLOR := Color(0.690196, 0.188235, 0.360784)
const DISABLED_COLOR := Color(0.376471, 0.376471, 0.439216)

@export var line_thickness := 4.0:
	set = set_line_thickness
@export var triangle_size := 12.0

var _color := Color(0, 0, 0)
var _line := Vector2.ZERO
var _collision_point := Vector2.ZERO

@onready var _parent: RayCast2D = get_parent()


func _ready() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)


func _draw() -> void:
	var ray_tip := _line if _collision_point == Vector2.ZERO else _collision_point
	draw_line(Vector2.ZERO, ray_tip, _color, line_thickness)

	# Draw an equilateral triangle at the end of the line
	var direction := ray_tip.normalized()
	var angle := direction.angle()
	var point1 := ray_tip + Vector2(cos(angle), sin(angle)) * triangle_size
	var point2 := ray_tip + Vector2(cos(angle + 2.0 * PI / 3.0), sin(angle + 2.0 * PI / 3.0)) * triangle_size
	var point3 := ray_tip + Vector2(cos(angle + 4.0 * PI / 3.0), sin(angle + 4.0 * PI / 3.0)) * triangle_size

	var triangle := PackedVector2Array([point1, point2, point3])
	draw_polygon(triangle, PackedColorArray([_color, _color, _color]))


func _physics_process(_delta: float) -> void:
	if not _parent.enabled:
		_color = DISABLED_COLOR
		queue_redraw()
		return

	_line = _parent.target_position
	if _parent.is_colliding():
		_color = PLAYER_COLLISION_COLOR
		_collision_point = _parent.get_collision_point() - _parent.global_position
		_collision_point = _collision_point.rotated(-_parent.global_rotation)
	else:
		_color = BASE_COLOR
		_collision_point = Vector2.ZERO
	queue_redraw()


func _get_configuration_warnings() -> PackedStringArray:
	return [] if _parent != null else ["Parent must be a RayCast2D"]


func set_line_thickness(value: float) -> void:
	line_thickness = value
	queue_redraw()
