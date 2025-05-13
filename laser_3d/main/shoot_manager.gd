extends Node3D

@onready var player = %FpsController
@onready var laser_sound = %LaserSound
@export var impact_decal_scene : PackedScene
@export var impact_scene : PackedScene
@export var shot_scene : PackedScene
@export var laser_beam_scene : PackedScene
@onready var impact_manager = %ImpactManager

var current_laser: Node3D = null
var current_impact: Node3D = null

func _ready():
	player.connect("laser_start", on_laser_start)
	player.connect("laser_update", on_laser_update)
	player.connect("laser_stop", on_laser_stop)

func on_laser_start(origin: Vector3, direction: Vector3, gun_end_position: Vector3):
	# Create the shot effect at the gun muzzle
	var shot = shot_scene.instantiate()
	shot.position = gun_end_position
	add_child(shot)
	
	# Create the laser beam
	current_laser = laser_beam_scene.instantiate()
	current_laser.position = gun_end_position
	add_child(current_laser)
	
	# Orient the laser in the direction of fire
	current_laser.transform = align_with_y(current_laser.transform, direction)
	# Start the laser
	current_laser.is_casting = true

func on_laser_update(origin: Vector3, direction: Vector3, gun_end_position: Vector3, collision: Dictionary):
	if not current_laser:
		return
	
	# Update laser position and rotation
	current_laser.global_position = gun_end_position
	current_laser.transform = align_with_y(current_laser.transform, direction)
	
	# Handle impact effects
	if not collision.is_empty():
		# If we hit something, update or create impact effects
		if not current_impact:
			current_impact = impact_scene.instantiate()
			add_child(current_impact)
			
			# Add impact decal if we hit a solid object
			if collision.collider and not collision.collider is Area3D:
				var impact_decal = impact_decal_scene.instantiate()
				impact_decal.position = collision.position
				impact_manager.add_child(impact_decal)
				impact_decal.transform = align_with_y(impact_decal.transform, collision.normal)
		
		# Update the impact effect position
		current_impact.position = collision.position
		current_impact.transform = align_with_y(current_impact.transform, collision.normal)
	elif current_impact:
		# We're no longer hitting anything, remove the impact effect
		current_impact.queue_free()
		current_impact = null

func on_laser_stop():
	# Stop the laser
	if current_laser:
		current_laser.is_casting = false
		# The laser will animate its disappearance before being removed
		await get_tree().create_timer(0.2).timeout
		current_laser.queue_free()
		current_laser = null
	
	# Remove the impact effect
	if current_impact:
		current_impact.queue_free()
		current_impact = null

# Custom align function for our laser - make it point in the direction of fire
func align_with_y(t, direction):
	# For laser beams, we want to orient so that z points in the direction
	t.basis.z = direction
	t.basis.x = Vector3.UP.cross(direction).normalized()
	t.basis.y = direction.cross(t.basis.x).normalized()
	return t

func node_3d_alpha(progress : float, node_3d : MeshInstance3D):
	node_3d.transparency = 1.0 - sin(progress * PI)
