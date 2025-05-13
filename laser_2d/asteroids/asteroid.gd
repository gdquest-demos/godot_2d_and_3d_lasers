extends StaticBody2D

var rotation_speed := randf_range(PI / 20.0, PI / 4.0)

@onready var sprite_2d: Sprite2D = $Sprite2D


func _process(delta: float) -> void:
	sprite_2d.rotate(rotation_speed * delta)
