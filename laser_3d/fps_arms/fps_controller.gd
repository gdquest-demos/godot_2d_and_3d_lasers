extends CharacterBody3D

signal laser_start(origin: Vector3, direction: Vector3, gun_end_position: Vector3)
signal laser_update(origin: Vector3, direction: Vector3, gun_end_position: Vector3, collision: Dictionary)
signal laser_stop()

@export_range(1.0, 10.0, 0.1) var speed := 5.0
@export_range(1.0, 10.0, 0.1) var jump_velocity := 4.5
@export_range(1.0, 10.0, 0.1) var base_acceleration_speed := 8.0

@onready var _camera: Camera3D = %Camera3D
@onready var _arms_viewport: ArmsViewport = %ArmsView
@onready var _collision_shape: CollisionShape3D = %CollisionShape3D
@onready var _neck: Node3D = %Neck
@onready var _crouch_ceiling_cast: ShapeCast3D = %CrouchCeilingCast

@onready var _foot_step: AudioStreamPlayer = %FootStep
@onready var _landing: AudioStreamPlayer = %Landing
@onready var _no_ammo: AudioStreamPlayer = %NoAmmo
@onready var _laser_sound: AudioStreamPlayer = %LaserSound

@onready var weapon_data = preload("res://laser_3d/resources/laser_gun_data.tres")

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var last_ammo_use_time := 0
var weapon_meter_range := 20.0
var look_direction := Vector2.ZERO
var is_crouching := false: set = set_is_crouching
var is_firing_laser := false
var laser_collision := {}


func _ready() -> void:
	weapon_data.connect("reloaded", func():
		_arms_viewport.reload()
	)
	_arms_viewport.apply_position_and_rotation(_camera.global_transform)
	_arms_viewport.footstep.connect(func on_character_stepped() -> void:
			if is_crouching:
				return
			_foot_step.pitch_scale = randfn(1.0, 0.05)
			_foot_step.play()
	)


func set_is_crouching(value: bool) -> void:
	if is_crouching == value:
		return
	if not value and _crouch_ceiling_cast.is_colliding():
		return

	is_crouching = value

	_collision_shape.position.y = 0.5 if is_crouching else 1.0
	_collision_shape.shape.height = 1.0 if is_crouching else 2.0

	var crouch_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	crouch_tween.tween_property(_neck, "position:y", 1.0 if is_crouching else 1.6, 0.25)


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion:
		look_direction = event.relative * 0.0025


func get_gun_end_position() -> Vector3:
	var camera_depth := _arms_viewport.camera.to_local(_arms_viewport.gun_end.global_position).length()
	var screen_position := _arms_viewport.camera.unproject_position(_arms_viewport.gun_end.global_position)
	return _camera.project_position(screen_position, camera_depth)


func _physics_process(delta: float) -> void:
	# Look handling
	var joystick_look_vector := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if joystick_look_vector.length() > 0.0:
		look_direction = joystick_look_vector * 2.0 * delta

	_camera.rotation.y -= look_direction.x
	_camera.rotation.x -= look_direction.y
	_camera.rotation.x = clamp(_camera.rotation.x, -1.2, 1.2)

	look_direction = Vector2.ZERO

	if not is_on_floor():
		velocity.y -= gravity * delta

	if is_on_floor():
		is_crouching = Input.is_action_pressed("crouching")

	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = jump_velocity

	var input_direction := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var movement_direction := input_direction.rotated(-_camera.rotation.y)

	if movement_direction.length() != 0.0:
		var walk_speed := speed
		if is_crouching:
			walk_speed *= 0.5
		var ground_velocity := Vector2(velocity.x, velocity.z)
		var velocity_change := speed * (1.0 if is_on_floor() else 0.2) * base_acceleration_speed * delta
		ground_velocity = ground_velocity.move_toward(movement_direction * walk_speed, velocity_change)
		velocity = Vector3(ground_velocity.x, velocity.y, ground_velocity.y)
	else:
		var drag_factor := 4.0 if is_on_floor() else 2.0
		var new_ground_velocity := velocity.move_toward(Vector3.ZERO, speed * drag_factor * delta)
		velocity = Vector3(new_ground_velocity.x, velocity.y, new_ground_velocity.z)

	var was_in_air := not is_on_floor()
	var vertical_velocity := velocity.y
	move_and_slide()
	var just_landed := was_in_air and is_on_floor()
	if just_landed:
		var impact_speed := remap(clamp(abs(vertical_velocity), 0.0, speed * 2.0),
		0.0, speed * 2.0, 0.0, 1.0)
		_landing.volume_db = impact_speed * 10.0
		_landing.pitch_scale = randfn(1.0, 0.1)
		_landing.play()

	var is_moving := Vector2(velocity.x, velocity.z).length() > 0.0
	_arms_viewport.is_walking = movement_direction.length() > 0.0 and is_on_floor() and is_moving

	# Laser weapon handling
	var is_weapon_busy := _arms_viewport.is_reloading
	var firing_laser := Input.is_action_pressed("shoot") and not is_weapon_busy

	# Handle laser start/stop events
	if firing_laser and not is_firing_laser:
		is_firing_laser = true
		_arms_viewport.fire()
		if not _laser_sound.playing:
			_laser_sound.pitch_scale = randfn(1.0, 0.05)
			_laser_sound.play()

		laser_start.emit(
			_camera.global_position,
			-_camera.transform.basis.z,
			get_gun_end_position()
		)
	elif not firing_laser and is_firing_laser:
		is_firing_laser = false
		_laser_sound.stop()
		laser_stop.emit()

	# Update laser position while firing
	if is_firing_laser:
		var space_state := get_world_3d().direct_space_state
		var ray_origin := _camera.global_position
		var ray_end := ray_origin - _camera.transform.basis.z * weapon_meter_range

		var ray_params := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		ray_params.collide_with_areas = true
		ray_params.collision_mask = 1

		var ray_result := space_state.intersect_ray(ray_params)
		laser_collision = ray_result if not ray_result.is_empty() else {}

		laser_update.emit(
			ray_origin,
			-_camera.transform.basis.z,
			get_gun_end_position(),
			laser_collision
		)
