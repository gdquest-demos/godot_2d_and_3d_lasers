## Simplified laser beam that casts along a raycast.
## Use `is_casting` to make the laser fire and stop.
@tool
extends RayCast2D

## Speed at which the laser extends when first fired, in pixels per seconds.
@export var cast_speed := 7000.0
## Maximum length of the laser in pixels.
@export var max_length := 1400.0
## Distance in pixels from the origin to start drawing and firing the laser.
@export var start_distance := 40.0
## If `true`, the laser is firing.
@export var is_casting := false: set = set_is_casting


func _ready() -> void:
	set_is_casting(is_casting)

	if not Engine.is_editor_hint():
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	target_position = target_position.move_toward(Vector2.RIGHT * max_length, cast_speed * delta)

	force_raycast_update()


func set_is_casting(new_value: bool) -> void:
	if is_casting == new_value:
		return
	is_casting = new_value

	set_physics_process(is_casting)

	if is_casting:
		target_position = Vector2.RIGHT * start_distance
	else:
		target_position = Vector2.ZERO
