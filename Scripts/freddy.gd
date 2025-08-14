extends CharacterBody3D

@onready var nav_agent = $NavigationAgent3D
@onready var TARGET : CharacterBody3D = get_tree().get_first_node_in_group("Player")
@export var SPEED = 8
@export var GRAVITY = -20.0  # Gravity for the enemy
@export var DIRECT_MOVEMENT_THRESHOLD = 2.0
@onready var FOOTSTEP_TIMER: Timer = $FootstepTimer
@onready var AUDIO_PLAYER: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var ANIM_PLAYER: AnimationPlayer = $Freddy/AnimationPlayer

# Navigation tracking
var navigation_ready = false
var target_update_timer = 0.0
var target_update_interval = 0.2  # Update more frequently - every 0.2 seconds
var use_fallback_movement = false
var last_valid_direction = Vector3.ZERO
var ground_check_ray: RayCast3D

func _ready():
	# Add to enemies group - CRITICAL!
	add_to_group("Enemies")
	
	# Create ground check raycast
	ground_check_ray = RayCast3D.new()
	ground_check_ray.target_position = Vector3(0, -2, 0)
	ground_check_ray.enabled = true
	add_child(ground_check_ray)
	
	# Debug: Check if we found the player
	if TARGET:
		print("Enemy found player at: ", TARGET.global_position)
	else:
		print("ERROR: Enemy could not find player!")
	
	# Configure NavigationAgent3D settings
	if nav_agent:
		nav_agent.path_desired_distance = 0.8
		nav_agent.target_desired_distance = 2.0
		nav_agent.path_max_distance = 50.0
		nav_agent.avoidance_enabled = false
		nav_agent.radius = 0.4  # Smaller collision radius
		nav_agent.height = 1.8
		
		# Connect signals
		nav_agent.navigation_finished.connect(_on_navigation_finished)
		nav_agent.target_reached.connect(_on_target_reached)
		nav_agent.path_changed.connect(_on_path_changed)
	
	# Wait for navigation setup
	await get_tree().create_timer(1.0).timeout
	_setup_navigation()

func _setup_navigation():
	var nav_map = get_world_3d().navigation_map
	if NavigationServer3D.map_is_active(nav_map):
		navigation_ready = true
		print("Enemy navigation ready at position: ", global_position)
		_start_following_player()
	else:
		print("Navigation not ready, using fallback movement")
		use_fallback_movement = true
		navigation_ready = true  # Allow movement with fallback

func _start_following_player():
	if TARGET and navigation_ready:
		update_target_location(TARGET.global_position)

func _physics_process(delta: float) -> void:
	# Handle freeze state
	if Global.freeze:
		_handle_freeze_state()
		return
	else:
		_handle_unfreeze_state()
	
	if not navigation_ready or not TARGET:
		return
	
	# Apply gravity first
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0  # Reset Y velocity when on ground
	
	# Update target more intelligently
	target_update_timer += delta
	var should_update_target = false
	
	# Regular periodic update
	if target_update_timer >= target_update_interval:
		should_update_target = true
		target_update_timer = 0.0
	
	# Update if navigation finished (reached old target)
	if nav_agent.is_navigation_finished():
		should_update_target = true
	
	# Update if player moved significantly from last target
	if TARGET:
		var current_target = nav_agent.get_target_position()
		var distance_moved = TARGET.global_position.distance_to(current_target)
		if distance_moved > 3.0:  # Player moved more than 3 units
			should_update_target = true
	
	if should_update_target and TARGET:
		update_target_location(TARGET.global_position)
	
	# Choose movement method - only affect X and Z velocity
	var distance_to_player = global_position.distance_to(TARGET.global_position)
	var horizontal_movement = Vector3.ZERO
	
	if use_fallback_movement or distance_to_player < DIRECT_MOVEMENT_THRESHOLD:
		horizontal_movement = _get_direct_movement_direction()
	else:
		horizontal_movement = _get_navigation_movement_direction()
	
	# Apply horizontal movement (preserve Y velocity for gravity)
	velocity.x = horizontal_movement.x * SPEED
	velocity.z = horizontal_movement.z * SPEED
	
	# Apply movement
	move_and_slide()
	
	# Handle audio
	_handle_footstep_audio()

func _get_navigation_movement_direction() -> Vector3:
	# Check if navigation path is valid
	if nav_agent.is_navigation_finished():
		return _get_direct_movement_direction()
	
	var current_location = global_position
	var next_location = nav_agent.get_next_path_position()
	var direction = (next_location - current_location).normalized()
	
	# Keep movement horizontal
	direction.y = 0
	direction = direction.normalized()
	
	# Check if we can actually reach the next position
	if direction.length() < 0.1:
		return _get_direct_movement_direction()
	
	# Store valid direction for fallback
	last_valid_direction = direction
	
	# Look at target
	_look_at_player()
	
	return direction

func _get_direct_movement_direction() -> Vector3:
	if not TARGET:
		return Vector3.ZERO
	
	# When using direct movement, always move toward current player position
	var direction_to_player = (TARGET.global_position - global_position).normalized()
	direction_to_player.y = 0  # Keep movement horizontal
	
	# Use shape casting instead of raycast for better collision detection
	var space_state = get_world_3d().direct_space_state
	var shape = CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), global_position + direction_to_player * 1.0)
	query.collision_mask = 1  # Only check layer 1 (walls)
	query.exclude = [self]  # Don't collide with self
	
	var collisions = space_state.intersect_shape(query)
	
	if collisions.is_empty():
		# Direct path is clear
		last_valid_direction = direction_to_player
		_look_at_player()
		return direction_to_player
	else:
		# Path blocked, try wall sliding
		return _handle_wall_sliding(direction_to_player)

func _handle_wall_sliding(blocked_direction: Vector3) -> Vector3:
	# Get the wall normal from collision
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 1, 0),
		global_position + Vector3(0, 1, 0) + blocked_direction * 1.5
	)
	query.collision_mask = 1  # Only walls
	
	var result = space_state.intersect_ray(query)
	
	if result.has("normal"):
		# Slide along the wall
		var wall_normal = result["normal"]
		var slide_direction = blocked_direction - wall_normal * blocked_direction.dot(wall_normal)
		slide_direction.y = 0
		slide_direction = slide_direction.normalized()
		
		if slide_direction.length() > 0.1:
			_look_at_player()  # Still look at player while sliding
			return slide_direction * 0.8  # Slower when sliding
	
	# If sliding fails, try perpendicular movement
	var right_dir = blocked_direction.cross(Vector3.UP).normalized()
	var left_dir = -right_dir
	
	# Test both perpendicular directions
	for test_dir in [right_dir, left_dir]:
		var test_query = PhysicsShapeQueryParameters3D.new()
		var test_shape = CapsuleShape3D.new()
		test_shape.radius = 0.4
		test_shape.height = 1.8
		test_query.shape = test_shape
		test_query.transform = Transform3D(Basis(), global_position + test_dir * 0.8)
		test_query.collision_mask = 1
		
		var test_collisions = space_state.intersect_shape(test_query)
		if test_collisions.is_empty():
			_look_at_player()
			return test_dir * 0.6  # Even slower when going around
	
	# If all else fails, use last valid direction or stop
	if last_valid_direction.length() > 0:
		return last_valid_direction * 0.3
	
	return Vector3.ZERO

func _look_at_player():
	if TARGET:
		var target_position = Vector3(
			TARGET.global_position.x,
			global_position.y,
			TARGET.global_position.z
		)
		look_at(target_position, Vector3.UP)

func _handle_freeze_state():
	if ANIM_PLAYER:
		ANIM_PLAYER.pause()
	# Keep gravity but stop horizontal movement
	velocity.x = 0
	velocity.z = 0
	if not is_on_floor():
		velocity.y += GRAVITY * get_physics_process_delta_time()
	move_and_slide()
	
	if AUDIO_PLAYER:
		AUDIO_PLAYER.stream_paused = true
	if FOOTSTEP_TIMER:
		FOOTSTEP_TIMER.paused = true

func _handle_unfreeze_state():
	if ANIM_PLAYER:
		ANIM_PLAYER.play()
	if AUDIO_PLAYER:
		AUDIO_PLAYER.stream_paused = false
	if FOOTSTEP_TIMER:
		FOOTSTEP_TIMER.paused = false

func _handle_footstep_audio():
	if velocity.length() > 0 and FOOTSTEP_TIMER and FOOTSTEP_TIMER.time_left <= 0:
		if AUDIO_PLAYER:
			AUDIO_PLAYER.pitch_scale = randf_range(0.8, 1.2)
			AUDIO_PLAYER.play()
		FOOTSTEP_TIMER.start(0.85)

func update_target_location(target_location):
	if not navigation_ready or not nav_agent:
		return
	
	# Always try navigation first
	nav_agent.set_target_position(target_location)
	
	# Check if target is reachable after a short delay
	await get_tree().process_frame
	
	if not nav_agent.is_target_reachable():
		print("Target not reachable via navigation, using fallback movement")
		use_fallback_movement = true
	else:
		use_fallback_movement = false
		print("Updated target to: ", target_location)

# Signal handlers
func _on_navigation_finished():
	if TARGET:
		update_target_location(TARGET.global_position)

func _on_target_reached():
	if TARGET:
		update_target_location(TARGET.global_position)

func _on_path_changed():
	# Reset fallback when we get a new valid path
	use_fallback_movement = false

# Debug function
func _input(event):
	if event.is_action_pressed("ui_accept"):
		print("=== ENEMY DEBUG ===")
		print("Navigation ready: ", navigation_ready)
		print("Use fallback: ", use_fallback_movement)
		print("Distance to player: ", global_position.distance_to(TARGET.global_position) if TARGET else "No target")
		print("Nav target reachable: ", nav_agent.is_target_reachable() if nav_agent else "No nav agent")
		print("Velocity: ", velocity)
		print("==================")
