extends CharacterBody3D

@onready var footstep_timer: Timer = $FootstepTimer
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var anim_player: AnimationPlayer = $Freddy/AnimationPlayer
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

@export var speed = 4.0  # Further reduced for better control
@export var gravity = -20.0
@export var path_update_interval = 0.3  # More frequent updates for better tracking

var target: CharacterBody3D
var path_update_timer = 0.0
var navigation_ready = false
var maze_generator: MazeGenerator3D
var stuck_timer = 0.0
var last_position = Vector3.ZERO
var stuck_check_interval = 0.5
var stuck_check_timer = 0.0
var consecutive_stuck_checks = 0
var last_valid_position = Vector3.ZERO

func _ready():
	add_to_group("Enemies")
	
	print("Enemy spawned at position: ", global_position)
	
	# Store initial position as last valid position
	last_valid_position = global_position
	
	# Find the maze generator
	maze_generator = get_tree().get_first_node_in_group("MazeGenerator")
	if not maze_generator:
		maze_generator = find_parent("*").find_child("MazeGenerator3D", true, false)
	
	# Configure navigation agent - CRITICAL SETTINGS
	if navigation_agent:
		# These settings MUST match your navigation mesh
		navigation_agent.radius = 0.8  # Slightly larger than navigation mesh for safety
		navigation_agent.height = 2.0
		navigation_agent.path_desired_distance = 0.5  # Closer to waypoints
		navigation_agent.target_desired_distance = 1.5  # Stop distance from target
		navigation_agent.path_max_distance = 20.0  # Allow longer path corrections
		navigation_agent.avoidance_enabled = true
		navigation_agent.neighbor_distance = 3.0
		navigation_agent.max_neighbors = 3
		navigation_agent.time_horizon = 1.5
		navigation_agent.max_speed = speed
		
		# Connect navigation signals
		navigation_agent.navigation_finished.connect(_on_navigation_finished)
		navigation_agent.target_reached.connect(_on_target_reached)
		navigation_agent.velocity_computed.connect(_on_velocity_computed)
		
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
	
	# Validate starting position is safe
	if not is_position_safe_for_navigation(global_position):
		print("Starting position not safe, finding better position...")
		var safe_start = find_safe_starting_position()
		if safe_start != Vector3.ZERO:
			global_position = safe_start
			last_valid_position = safe_start
			print("Moved to safe starting position:", safe_start)
	
	navigation_ready = true
	last_position = global_position

func find_safe_starting_position() -> Vector3:
	"""Find a safe position that's actually on the navigation mesh"""
	
	if not maze_generator:
		return Vector3.ZERO
	
	# Get all possible spawn positions from maze generator
	var possible_positions = maze_generator.get_possible_spawn_positions()
	
	# Test each position for navigation safety
	for pos in possible_positions:
		if is_position_safe_for_navigation(pos) and global_position.distance_to(pos) < 20.0:
			return pos
	
	# Fallback: try the player spawn position
	var player_spawn = maze_generator.get_player_spawn_position()
	if is_position_safe_for_navigation(player_spawn):
		return player_spawn
	
	return Vector3.ZERO

func is_position_safe_for_navigation(pos: Vector3) -> bool:
	"""Check if position is on navigation mesh and safe from walls"""
	
	# Check if position is on navigation mesh
	if navigation_agent and navigation_agent.get_navigation_map().is_valid():
		var nav_map = navigation_agent.get_navigation_map()
		var closest_point = NavigationServer3D.map_get_closest_point(nav_map, pos)
		
		# Position is not safe if it's too far from navigation mesh
		if pos.distance_to(closest_point) > 1.0:
			return false
	
	# Check for nearby walls using multiple raycasts
	var space_state = get_world_3d().direct_space_state
	var safety_radius = 1.2  # Minimum distance from walls
	
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
	
	return true

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
	
	# Check if we're stuck periodically
	stuck_check_timer += delta
	if stuck_check_timer >= stuck_check_interval:
		check_if_stuck()
		stuck_check_timer = 0.0
	
	# Try navigation first, fallback to direct movement only if necessary
	if navigation_agent and try_navigation_movement(delta):
		# Navigation successful
		consecutive_stuck_checks = 0
	else:
		# Navigation failed, use safe direct movement
		use_safe_direct_movement(delta)
	
	move_and_slide()
	handle_footsteps()

func try_navigation_movement(delta) -> bool:
	"""Try to use navigation agent movement. Returns true if successful."""
	
	if not navigation_agent.get_navigation_map().is_valid():
		print("Navigation map invalid")
		return false
	
	# Update target more frequently for better corner navigation
	path_update_timer += delta
	if path_update_timer >= path_update_interval:
		path_update_timer = 0.0
		var target_pos = target.global_position
		
		# Ensure target is at floor level for navigation
		target_pos.y = 0.1
		navigation_agent.target_position = target_pos
		
		print("Updated navigation target to: ", target_pos)
		print("Navigation finished: ", navigation_agent.is_navigation_finished())
		print("Distance to target: ", global_position.distance_to(target_pos))
	
	# Check if navigation has a valid path
	if navigation_agent.is_navigation_finished():
		print("Navigation finished - no path available")
		return false
	
	var next_path_position = navigation_agent.get_next_path_position()
	var direction = (next_path_position - global_position)
	direction.y = 0
	
	var distance_to_waypoint = direction.length()
	print("Distance to next waypoint: ", distance_to_waypoint, " at ", next_path_position)
	
	# Only move if we're not too close to the waypoint
	if distance_to_waypoint > navigation_agent.path_desired_distance:
		direction = direction.normalized()
		
		# Use avoidance velocity for smooth movement
		var desired_velocity = direction * speed * 0.6  # Reduced speed for better control
		navigation_agent.set_velocity(desired_velocity)
		
		print("Moving towards waypoint with velocity: ", desired_velocity)
		return true
	else:
		# Close to waypoint, slow down
		velocity.x = lerp(velocity.x, 0.0, 8.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 8.0 * delta)
		print("Close to waypoint, slowing down")
		return true

func _on_velocity_computed(safe_velocity: Vector3):
	"""Called by navigation agent with collision-free velocity"""
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z
	
	# Update last valid position when moving successfully
	if safe_velocity.length() > 0.1:
		last_valid_position = global_position
	
	# Handle rotation
	if safe_velocity.length() > 0.1:
		var look_direction = Vector3(safe_velocity.x, 0, safe_velocity.z).normalized()
		var look_target = global_position + look_direction
		var target_transform = transform.looking_at(look_target, Vector3.UP)
		transform = transform.interpolate_with(target_transform, 3.0 * get_physics_process_delta_time())

func use_safe_direct_movement(delta):
	"""Fallback direct movement with enhanced wall avoidance"""
	
	if not target:
		return
	
	var direction_to_player = (target.global_position - global_position).normalized()
	direction_to_player.y = 0
	
	# Check if direct path is blocked
	if will_hit_wall(direction_to_player, delta):
		# Try to find a way around the wall
		var avoid_direction = find_best_avoidance_direction(direction_to_player)
		if avoid_direction != Vector3.ZERO:
			velocity.x = avoid_direction.x * speed * 0.3
			velocity.z = avoid_direction.z * speed * 0.3
			
			# Update last valid position when moving
			last_valid_position = global_position
		else:
			# Can't find a way around - stop
			velocity.x = 0
			velocity.z = 0
	else:
		# Direct path is clear
		velocity.x = direction_to_player.x * speed * 0.4
		velocity.z = direction_to_player.z * speed * 0.4
		
		# Update last valid position when moving
		last_valid_position = global_position
	
	# Look at player
	if direction_to_player.length() > 0.1:
		var look_target = Vector3(target.global_position.x, global_position.y, target.global_position.z)
		var target_transform = transform.looking_at(look_target, Vector3.UP)
		transform = transform.interpolate_with(target_transform, 2.0 * delta)

func will_hit_wall(direction: Vector3, delta: float) -> bool:
	"""Enhanced wall detection with multiple raycasts"""
	
	var space_state = get_world_3d().direct_space_state
	var from = global_position + Vector3(0, 0.5, 0)
	var move_distance = speed * delta * 2.0  # Look ahead
	
	# Main raycast
	var to_main = from + direction.normalized() * move_distance
	var query_main = PhysicsRayQueryParameters3D.create(from, to_main)
	query_main.collision_mask = 1
	query_main.exclude = [self]
	
	if space_state.intersect_ray(query_main):
		return true
	
	# Side raycasts to check for corners
	var perpendicular = Vector3(-direction.z, 0, direction.x).normalized() * 0.4
	
	var to_left = from + (direction.normalized() * move_distance) + perpendicular
	var to_right = from + (direction.normalized() * move_distance) - perpendicular
	
	var query_left = PhysicsRayQueryParameters3D.create(from + perpendicular * 0.5, to_left)
	var query_right = PhysicsRayQueryParameters3D.create(from - perpendicular * 0.5, to_right)
	
	query_left.collision_mask = 1
	query_left.exclude = [self]
	query_right.collision_mask = 1
	query_right.exclude = [self]
	
	return space_state.intersect_ray(query_left) or space_state.intersect_ray(query_right)

func find_best_avoidance_direction(blocked_direction: Vector3) -> Vector3:
	"""Find the best direction to avoid walls"""
	
	# Test multiple angles to find the best path
	var test_angles = [30, -30, 60, -60, 90, -90, 120, -120]
	var best_direction = Vector3.ZERO
	var best_clear_distance = 0.0
	
	for angle in test_angles:
		var test_direction = blocked_direction.rotated(Vector3.UP, deg_to_rad(angle))
		var clear_distance = get_clear_distance(test_direction)
		
		if clear_distance > best_clear_distance:
			best_clear_distance = clear_distance
			best_direction = test_direction
	
	# Only return direction if it has reasonable clearance
	return best_direction if best_clear_distance > 1.0 else Vector3.ZERO

func get_clear_distance(direction: Vector3) -> float:
	"""Get how far we can move in a direction before hitting a wall"""
	
	var space_state = get_world_3d().direct_space_state
	var from = global_position + Vector3(0, 0.5, 0)
	var max_distance = 3.0
	var to = from + direction.normalized() * max_distance
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	if result:
		return from.distance_to(result.position)
	else:
		return max_distance

func check_if_stuck():
	"""Improved stuck detection with less aggressive unsticking"""
	
	var movement_threshold = 0.2
	var current_distance = global_position.distance_to(last_position)
	
	if current_distance < movement_threshold:
		consecutive_stuck_checks += 1
		
		# Only attempt unsticking after multiple consecutive stuck checks
		if consecutive_stuck_checks >= 4:  # 2 seconds of being stuck
			print("Enemy stuck for 2+ seconds - attempting gentle unstick")
			try_gentle_unstick()
			consecutive_stuck_checks = 0  # Reset counter
	else:
		consecutive_stuck_checks = 0
		# Update last position only when actually moving
		last_position = global_position

func try_gentle_unstick():
	"""Gentle unstick that doesn't teleport through walls"""
	
	print("Attempting gentle unstick...")
	
	# First try: nudge slightly in a clear direction
	var nudge_directions = [
		Vector3(0.5, 0, 0), Vector3(-0.5, 0, 0),
		Vector3(0, 0, 0.5), Vector3(0, 0, -0.5),
		Vector3(0.35, 0, 0.35), Vector3(-0.35, 0, -0.35)
	]
	
	for nudge in nudge_directions:
		var test_position = global_position + nudge
		if is_position_safe_for_navigation(test_position):
			global_position = test_position
			velocity = Vector3.ZERO
			print("Gentle nudge successful")
			return
	
	# Second try: move back to last known valid position
	if last_valid_position != Vector3.ZERO and last_valid_position.distance_to(global_position) < 5.0:
		if is_position_safe_for_navigation(last_valid_position):
			global_position = last_valid_position
			velocity = Vector3.ZERO
			print("Returned to last valid position")
			return
	
	# Third try: find nearest safe position from maze generator
	if maze_generator:
		var safe_positions = maze_generator.get_possible_spawn_positions()
		var nearest_safe = Vector3.ZERO
		var nearest_distance = INF
		
		for pos in safe_positions:
			var distance = global_position.distance_to(pos)
			if distance < nearest_distance and distance < 10.0:  # Only consider nearby positions
				if is_position_safe_for_navigation(pos):
					nearest_distance = distance
					nearest_safe = pos
		
		if nearest_safe != Vector3.ZERO:
			global_position = nearest_safe
			last_valid_position = nearest_safe
			velocity = Vector3.ZERO
			print("Moved to nearest safe position")
			return
	
	print("Could not unstick safely - enemy will continue trying to move")

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
	if target and navigation_agent and randf() < 0.3:
		call_deferred("set_new_target")

func set_new_target():
	if navigation_agent and navigation_agent.get_navigation_map().is_valid():
		var nav_map = navigation_agent.get_navigation_map()
		var safe_target = NavigationServer3D.map_get_closest_point(nav_map, target.global_position)
		navigation_agent.target_position = safe_target

func _on_target_reached():
	# When reaching target, wait a moment before setting new path
	await get_tree().create_timer(0.2).timeout
	set_new_target()

func update_target_location(target_location: Vector3):
	if navigation_agent and navigation_ready and navigation_agent.get_navigation_map().is_valid():
		var nav_map = navigation_agent.get_navigation_map()
		var safe_target = NavigationServer3D.map_get_closest_point(nav_map, target_location)
		navigation_agent.target_position = safe_target

# Enhanced debug function
func _input(event):
	if event.is_action_pressed("ui_accept"):
		print("=== FREDDY DEBUG ===")
		print("Position: ", global_position)
		print("Target: ", target.global_position if target else "None")
		print("Velocity: ", velocity)
		print("Consecutive stuck checks: ", consecutive_stuck_checks)
		print("Last valid position: ", last_valid_position)
		print("Position safe for nav: ", is_position_safe_for_navigation(global_position))
		if navigation_agent:
			print("Nav target: ", navigation_agent.target_position)
			print("Nav finished: ", navigation_agent.is_navigation_finished())
			print("Nav map valid: ", navigation_agent.get_navigation_map().is_valid())
			print("Agent radius: ", navigation_agent.radius)
			if navigation_agent.get_navigation_map().is_valid():
				var nav_map = navigation_agent.get_navigation_map()
				var closest = NavigationServer3D.map_get_closest_point(nav_map, global_position)
				print("Closest nav point: ", closest)
				print("Distance to nav mesh: ", global_position.distance_to(closest))
		print("===================")
