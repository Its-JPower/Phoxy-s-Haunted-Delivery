extends CharacterBody3D

@onready var footstep_timer: Timer = $FootstepTimer
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var anim_player: AnimationPlayer = $Freddy/AnimationPlayer
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

@export var speed = 6.0  # Reduced speed for better control
@export var gravity = -20.0
@export var path_update_interval = 0.5  # Less frequent updates

var target: CharacterBody3D
var path_update_timer = 0.0
var navigation_ready = false
var maze_generator: MazeGenerator3D
var stuck_timer = 0.0
var last_position = Vector3.ZERO
var wall_avoidance_timer = 0.0

func _ready():
	add_to_group("Enemies")
	
	print("Enemy spawned at position: ", global_position)
	
	# Find the maze generator
	maze_generator = get_tree().get_first_node_in_group("MazeGenerator")
	if not maze_generator:
		maze_generator = find_parent("*").find_child("MazeGenerator3D", true, false)
	
	# Configure navigation agent with VERY conservative settings
	if navigation_agent:
		# Much larger radius to stay far from walls
		navigation_agent.radius = 1.2  # INCREASED - stay much further from walls
		navigation_agent.height = 2.0
		navigation_agent.path_desired_distance = 1.5  # Stay further from waypoints
		navigation_agent.target_desired_distance = 3.0  # Stop much further from target
		navigation_agent.path_max_distance = 50.0
		navigation_agent.avoidance_enabled = true
		navigation_agent.neighbor_distance = 4.0
		navigation_agent.max_neighbors = 3
		navigation_agent.time_horizon = 2.0
		navigation_agent.max_speed = speed
		
		# Connect navigation signals
		navigation_agent.navigation_finished.connect(_on_navigation_finished)
		navigation_agent.target_reached.connect(_on_target_reached)
		
		print("Navigation agent configured with radius: ", navigation_agent.radius)
	
	# Wait for navigation to be ready
	call_deferred("setup_navigation")

func setup_navigation():
	# Wait for navigation map to be ready
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	target = get_tree().get_first_node_in_group("Player")
	if not target:
		print("ERROR: No player found!")
		return
	
	print("Enemy found player")
	
	# Move to a safe starting position
	var safe_start = find_safe_starting_position()
	if safe_start != Vector3.ZERO:
		global_position = safe_start
		print("Moved to safe starting position")
	
	navigation_ready = true
	last_position = global_position

func find_safe_starting_position() -> Vector3:
	"""Find a safe position away from walls"""
	
	# Try positions in a spiral pattern around current position
	var test_positions = []
	var cell_size = 4.0  # Assuming your cell size
	
	for radius in range(1, 5):  # Test increasing distances
		for angle in range(0, 360, 45):  # Test 8 directions
			var offset = Vector3(
				cos(deg_to_rad(angle)) * radius * cell_size,
				0,
				sin(deg_to_rad(angle)) * radius * cell_size
			)
			test_positions.append(global_position + offset)
	
	# Test each position for safety
	for pos in test_positions:
		if is_position_safe(pos):
			return pos
	
	return Vector3.ZERO  # No safe position found

func is_position_safe(pos: Vector3) -> bool:
	"""Check if a position is safe (not too close to walls)"""
	
	var space_state = get_world_3d().direct_space_state
	var safety_radius = 2.0  # Minimum distance from walls
	
	# Check 8 directions around the position
	for angle in range(0, 360, 45):
		var direction = Vector3(cos(deg_to_rad(angle)), 0, sin(deg_to_rad(angle)))
		var from = pos + Vector3(0, 0.5, 0)
		var to = from + direction * safety_radius
		
		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = 1  # Wall layer
		query.exclude = [self]
		
		var result = space_state.intersect_ray(query)
		if result:
			return false  # Too close to a wall
	
	return true  # Position is safe

func _physics_process(delta):
	# Handle freeze
	if Global.freeze:
		handle_freeze()
		return
	else:
		handle_unfreeze()
	
	if not target or not navigation_ready:
		return
	
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0
	
	# Check if we're stuck
	check_if_stuck(delta)
	
	# Wall avoidance timer
	wall_avoidance_timer -= delta
	
	# Use navigation if available, otherwise use safe direct movement
	if navigation_agent and use_navigation_movement(delta):
		pass  # Navigation handled movement
	else:
		use_safe_direct_movement(delta)
	
	move_and_slide()
	handle_footsteps()
	
	# Update last position for stuck detection
	last_position = global_position

func use_navigation_movement(delta) -> bool:
	"""Try to use navigation agent movement. Returns true if successful."""
	
	# Update target periodically
	path_update_timer += delta
	if path_update_timer >= path_update_interval:
		path_update_timer = 0.0
		navigation_agent.target_position = target.global_position
	
	# Check if navigation is working
	if navigation_agent.is_navigation_finished():
		return false  # Navigation failed
	
	var next_path_position = navigation_agent.get_next_path_position()
	var direction = (next_path_position - global_position)
	direction.y = 0
	
	var distance_to_waypoint = direction.length()
	
	# Only move if we're not too close to the waypoint
	if distance_to_waypoint > navigation_agent.path_desired_distance:
		direction = direction.normalized()
		
		# CRITICAL: Always check for walls before moving
		if not will_hit_wall(direction, delta):
			velocity.x = direction.x * speed * 0.7  # Reduced speed for safety
			velocity.z = direction.z * speed * 0.7
			
			# Smooth rotation
			if direction.length() > 0.1:
				var look_target = global_position + direction
				var target_transform = transform.looking_at(look_target, Vector3.UP)
				transform = transform.interpolate_with(target_transform, 3.0 * delta)
			
			return true
		else:
			# Wall detected - stop and use direct movement
			velocity.x = 0
			velocity.z = 0
			wall_avoidance_timer = 1.0  # Use direct movement for 1 second
			return false
	else:
		# Close to waypoint, slow down
		velocity.x = lerp(velocity.x, 0.0, 5.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 5.0 * delta)
		return true

func use_safe_direct_movement(delta):
	"""Safe direct movement with wall avoidance"""
	
	if not target:
		return
	
	var direction_to_player = (target.global_position - global_position).normalized()
	direction_to_player.y = 0
	
	# Check if direct path is blocked
	if will_hit_wall(direction_to_player, delta):
		# Try to find a way around the wall
		var avoid_direction = find_wall_avoidance_direction(direction_to_player)
		if avoid_direction != Vector3.ZERO:
			velocity.x = avoid_direction.x * speed * 0.4
			velocity.z = avoid_direction.z * speed * 0.4
		else:
			# Can't find a way around - stop
			velocity.x = 0
			velocity.z = 0
	else:
		# Direct path is clear
		velocity.x = direction_to_player.x * speed * 0.5
		velocity.z = direction_to_player.z * speed * 0.5
	
	# Look at player
	if direction_to_player.length() > 0.1:
		var look_target = Vector3(target.global_position.x, global_position.y, target.global_position.z)
		var target_transform = transform.looking_at(look_target, Vector3.UP)
		transform = transform.interpolate_with(target_transform, 2.0 * delta)

func will_hit_wall(direction: Vector3, delta: float) -> bool:
	"""Check if moving in a direction will hit a wall"""
	
	var space_state = get_world_3d().direct_space_state
	var from = global_position + Vector3(0, 0.5, 0)
	var move_distance = speed * delta * 3.0  # Look ahead 3 frames
	var to = from + direction.normalized() * move_distance
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Wall layer
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	return result != null

func find_wall_avoidance_direction(blocked_direction: Vector3) -> Vector3:
	"""Find a direction to avoid walls"""
	
	# Try directions to the left and right of the blocked direction
	var avoid_angles = [45, -45, 90, -90, 135, -135]
	
	for angle in avoid_angles:
		var test_direction = blocked_direction.rotated(Vector3.UP, deg_to_rad(angle))
		if not will_hit_wall(test_direction, get_physics_process_delta_time()):
			return test_direction
	
	return Vector3.ZERO  # No clear direction found

func check_if_stuck(delta):
	"""Check if the enemy is stuck and try to unstick"""
	
	var movement_threshold = 0.1
	if global_position.distance_to(last_position) < movement_threshold:
		stuck_timer += delta
		
		if stuck_timer > 2.0:  # Stuck for 2 seconds
			print("Enemy appears stuck - trying to unstick")
			unstick_enemy()
			stuck_timer = 0.0
	else:
		stuck_timer = 0.0

func unstick_enemy():
	"""Try to unstick the enemy"""
	
	# Try to move to a nearby safe position
	var safe_pos = find_safe_starting_position()
	if safe_pos != Vector3.ZERO and safe_pos.distance_to(global_position) < 20.0:
		global_position = safe_pos
		velocity = Vector3.ZERO
		print("Moved enemy to unstick")
		return
	
	# If that fails, try moving in a random direction
	for i in range(8):
		var random_direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		if not will_hit_wall(random_direction, 0.1):
			velocity.x = random_direction.x * speed * 0.3
			velocity.z = random_direction.z * speed * 0.3
			print("Using random direction to unstick")
			break

func handle_freeze():
	if anim_player:
		anim_player.pause()
	if audio_player:
		audio_player.stream_paused = true
	if footstep_timer:
		footstep_timer.paused = true
	
	velocity.x = 0
	velocity.z = 0
	if not is_on_floor():
		velocity.y += gravity * get_physics_process_delta_time()
	move_and_slide()

func handle_unfreeze():
	if anim_player:
		anim_player.play()
	if audio_player:
		audio_player.stream_paused = false
	if footstep_timer:
		footstep_timer.paused = false

func handle_footsteps():
	if velocity.length() > 0.5 and footstep_timer and footstep_timer.time_left <= 0:
		if audio_player:
			audio_player.pitch_scale = randf_range(0.8, 1.2)
			audio_player.play()
		footstep_timer.start(0.85)

func _on_navigation_finished():
	if target and navigation_agent and randf() < 0.2:
		call_deferred("set_new_target")

func set_new_target():
	navigation_agent.target_position = target.global_position

func _on_target_reached():
	pass

func update_target_location(target_location: Vector3):
	if navigation_agent and navigation_ready:
		navigation_agent.target_position = target_location

# Debug function
func _input(event):
	if event.is_action_pressed("ui_accept"):
		print("=== FREDDY DEBUG ===")
		print("Position: ", global_position)
		print("Target: ", target.global_position if target else "None")
		print("Velocity: ", velocity)
		print("Stuck timer: ", stuck_timer)
		print("Wall avoidance timer: ", wall_avoidance_timer)
		if navigation_agent:
			print("Nav target: ", navigation_agent.target_position)
			print("Nav finished: ", navigation_agent.is_navigation_finished())
			print("Agent radius: ", navigation_agent.radius)
		print("Is position safe: ", is_position_safe(global_position))
		print("===================")
