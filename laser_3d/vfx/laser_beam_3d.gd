## Casts a laser along a raycast, emitting particles on the impact point.
## This 3D version is based on the 2D laser in laser_beam_2d.gd
extends RayCast3D

## Speed at which the laser extends when first fired, in meters per seconds.
@export var cast_speed := 40.0
## Maximum length of the laser in meters.
@export var max_length := 20.0
## Base duration of the tween animation in seconds.
@export var growth_time := 0.1
## How wide the laser beam is
@export var beam_width := 0.1

## If `true`, the laser is firing.
## It plays appearing and disappearing animations when it's not animating.
var is_casting := false: set = set_is_casting

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var casting_particles: GPUParticles3D = $CastingParticles
@onready var collision_particles: GPUParticles3D = $CollisionParticles
@onready var beam_particles: GPUParticles3D = $BeamParticles

var tween: Tween
var current_length := 0.0


func _ready() -> void:
	set_physics_process(false)
	current_length = 0.0
	_update_beam_mesh()


func _physics_process(delta: float) -> void:
	var cast_point := target_position

	current_length = min(current_length + cast_speed * delta, max_length)
	target_position = Vector3(0, 0, current_length)

	force_raycast_update()

	collision_particles.emitting = is_colliding()

	if is_colliding():
		cast_point = to_local(get_collision_point())
		collision_particles.global_position = get_collision_point()

		# Align collision particles with the normal
		var normal := get_collision_normal()
		if normal != Vector3.ZERO:
			var look_at_pos = get_collision_point() + normal
			collision_particles.look_at(look_at_pos, Vector3.UP)

	# Update the beam mesh to match the raycast
	if current_length > 0.0:
		var beam_length = cast_point.length()
		_update_beam_mesh(beam_length)

		# Update beam particles to follow along the laser
		beam_particles.position = Vector3(0, 0, beam_length * 0.5)
		# Scale the emission box to match the laser length
		var emission_shape = beam_particles.process_material.emission_box_extents
		emission_shape.z = beam_length * 0.5
		beam_particles.process_material.emission_box_extents = emission_shape


func set_is_casting(new_value: bool) -> void:
	if is_casting == new_value:
		return

	is_casting = new_value

	if is_casting:
		current_length = 0.0
		_update_beam_mesh()
		appear()
	else:
		disappear()

	set_physics_process(is_casting)
	beam_particles.emitting = is_casting
	casting_particles.emitting = is_casting


## Updates the beam mesh size and position to match the current length.
func _update_beam_mesh(beam_length: float = 0.0) -> void:
	if beam_length > 0:
		mesh_instance.mesh.size.z = beam_length
		mesh_instance.position.z = beam_length * 0.5


func appear() -> void:
	if tween and tween.is_running():
		tween.kill()

	tween = create_tween()
	mesh_instance.mesh.size.x = 0
	mesh_instance.mesh.size.y = 0
	tween.tween_property(mesh_instance.mesh, "size:x", beam_width, growth_time).from(0)
	tween.parallel().tween_property(mesh_instance.mesh, "size:y", beam_width, growth_time).from(0)


func disappear() -> void:
	if tween and tween.is_running():
		tween.kill()

	tween = create_tween()
	tween.tween_property(mesh_instance.mesh, "size:x", 0, growth_time)
	tween.parallel().tween_property(mesh_instance.mesh, "size:y", 0, growth_time)
	tween.tween_callback(func(): current_length = 0.0)
