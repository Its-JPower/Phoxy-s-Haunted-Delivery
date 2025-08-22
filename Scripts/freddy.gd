extends CharacterBody3D

@onready var footstep_timer: Timer = $FootstepTimer
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var anim_player: AnimationPlayer = $Freddy/AnimationPlayer
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

@export var speed = 3.5
@export var gravity = -20.0
@export var path_update_interval = 0.5  # How often to recalculate path

var target: CharacterBody3D
var path_update_timer = 0.0
var navigation_ready = false
var maze_generator: MazeGenerator3D

# Improved stuck detection
var position_history: Array[Vector3] = []
var stuck_threshold = 0.5  # Minimum movement in stuck_check_time
var stuck_check_time = 2.0
var last_stuck_check_time = 0.0

# Path following
var current_path: PackedVector3Array = []
var path_index = 0
var waypoint_reached_distance = 1.0

func _ready():
	add_to_group("Enemies")
	print("Enemy spawned at position: ", global_position)
	
	# Find the maze generator
	maze_generator = get_tree().get_first_node_in_group("MazeGenerator")
	if not maze_generator:
		maze_generator = find_parent("*").find_child("MazeGenerator3D", true, false)
	
	# Configure navigation agent for maze navigation
	if navigation_agent:
		navigation_agent.radius = 0.4  # Smaller radius for tighter spaces
		navigation_agent.height = 2.0
		navigation_agent.path_desired_distance = 0.3
		navigation_agent.target_desired_distance = 1.0
		navigation_agent.path_max_distance = 50.0  # Allow longer paths through maze
		navigation_agent.avoidance_enabled = true
		navigation_agent.neighbor_distance = 2.0
		navigation_agent.max_neighbors = 2
		navigation_agent.time_horizon = 1.0
		
		# Connect signals
		navigation_agent.navigation_finished.connect(_on_navigation_finished)
		navigation_agent.target_reached.connect(_on_target_reached)
		navigation_agent.velocity_computed.connect(_on_velocity_computed)
		
		print("Navigation agent configured for maze")
	
	# Setup navigation after scene is ready
	call_deferred("setup_navigation")

func setup_navigation():
	# Wait for navigation to be fully ready
	for i in range(5):
		await get_tree().physics_frame
	
	target = get_tree().get_first_node_in_group("Player")
	if not target:
		print("ERROR: No player found!")
		return
	
	print("Enemy found player at: ", target.global_position)
	
	# Validate and adjust starting position
	var safe_position = find_nearest_navigation_point(global_position)
	if safe_position != global_position:
		global_position = safe_position
		print("Adjusted enemy position to: ", safe_position)
	
	navigation_ready = true
	
	# Start position tracking
	position_history.clear()
	position_history.append(global_position)

func find_nearest_navigation_point(pos: Vector3) -> Vector3:
	"""Find the nearest valid point on the navigation mesh"""
	if not navigation_agent or not navigation_agent.get_navigation_map().is_valid():
		return pos
	
	var nav_map = navigation_agent.get_navigation_map()
	var closest_point = NavigationServer3D.map_get_closest_point(nav_map, pos)
	
	# If the closest point is too far, try to find a better one
	if pos.distance_to(closest_point) > 2.0:
		print("Position too far from nav mesh, searching for better position...")
		
		if maze_generator:
			var spawn_positions = maze_generator.get_possible_spawn_positions()
			var best_position = pos
			var best_distance = INF
			
			for spawn_pos in spawn_positions:
				var distance = pos.distance_to(spawn_pos)
				if distance < best_distance:
					var nav_closest = NavigationServer3D.map_get_closest_point(nav_map, spawn_pos)
					if spawn_pos.distance_to(nav_closest) < 1.0:  # Good nav mesh coverage
						best_distance = distance
						best_position = spawn_pos
			
			return best_position
	
	return closest_point

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
	
	# Update position history for stuck detection
	update_position_tracking(delta)
	
	# Update navigation path periodically
	path_update_timer += delta
	if path_update_timer >= path_update_interval:
		path_update_timer = 0.0
		update_navigation_target()
	
	# Move using navigation
	navigate_to_target(delta)
	
	move_and_slide()
	handle_footsteps()

func update_position_tracking(delta):
	"""Track position history for improved stuck detection"""
	last_stuck_check_time += delta
	
	if last_stuck_check_time >= 0.5:  # Update every 0.5 seconds
		position_history.append(global_position)
		
		# Keep only recent positions (last 4 seconds)
		var max_history = int(stuck_check_time / 0.5)
		if position_history.size() > max_history:
			position_history.pop_front()
		
		# Check if stuck
		if position_history.size() >= max_history:
			check_if_really_stuck()
		
		last_stuck_check_time = 0.0

func check_if_really_stuck():
	"""Improved stuck detection using position history"""
	if position_history.size() < 2:
		return
	
	var oldest_position = position_history[0]
	var current_position = position_history[-1]
	var total_movement = oldest_position.distance_to(current_position)
	
	if total_movement < stuck_threshold:
		print("Enemy is stuck! Total movement: ", total_movement, " in ", stuck_check_time, " seconds")
		attempt_unstuck()

func attempt_unstuck():
	"""Smart unstuck that respects navigation mesh"""
	print("Attempting to unstuck enemy...")
	
	if not navigation_agent or not navigation_agent.get_navigation_map().is_valid():
		return
	
	var nav_map = navigation_agent.get_navigation_map()
	
	# Try to find a nearby valid navigation point
	var search_positions = [
		global_position + Vector3(1, 0, 0),
		global_position + Vector3(-1, 0, 0),
		global_position + Vector3(0, 0, 1),
		global_position + Vector3(0, 0, -1),
		global_position + Vector3(1, 0, 1),
		global_position + Vector3(-1, 0, -1),
		global_position + Vector3(1, 0, -1),
		global_position + Vector3(-1, 0, 1)
	]
	
	for test_pos in search_positions:
		var nav_point = NavigationServer3D.map_get_closest_point(nav_map, test_pos)
		
		# Check if this point is actually accessible
		if test_pos.distance_to(nav_point) < 0.5 and is_path_clear_to_position(nav_point):
			global_position = nav_point
			velocity = Vector3.ZERO
			position_history.clear()
			position_history.append(global_position)
			
			# Recalculate path immediately
			call_deferred("update_navigation_target")
			print("Successfully unstuck to position: ", nav_point)
			return
	
	print("Could not find suitable unstuck position")

func is_path_clear_to_position(pos: Vector3) -> bool:
	"""Check if we can move to a position without hitting walls"""
	var space_state = get_world_3d().direct_space_state
	var from = global_position + Vector3(0, 0.5, 0)
	var to = pos + Vector3(0, 0.5, 0)
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Wall collision layer
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	return result.is_empty()

func update_navigation_target():
	"""Update the navigation agent's target position"""
	if not navigation_agent or not target:
		return
	
	if not navigation_agent.get_navigation_map().is_valid():
		print("Navigation map not valid")
		return
	
	var target_pos = target.global_position
	
	# Ensure target is on navigation mesh
	var nav_map = navigation_agent.get_navigation_map()
	var nav_target = NavigationServer3D.map_get_closest_point(nav_map, target_pos)
	
	# Only update if target has moved significantly or we don't have a target
	var current_target = navigation_agent.target_position
	if current_target.distance_to(nav_target) > 1.0 or navigation_agent.is_navigation_finished():
		navigation_agent.target_position = nav_target
		print("Updated navigation target to: ", nav_target, " (player at: ", target_pos, ")")

func navigate_to_target(delta):
	"""Main navigation movement function"""
	if not navigation_agent:
		return
	
	# Check if we have a valid path
	if navigation_agent.is_navigation_finished():
		# No path available, try to get a new one
		update_navigation_target()
		return
	
	# Get next position in path
	var next_path_position = navigation_agent.get_next_path_position()
	var direction_to_next = (next_path_position - global_position)
	direction_to_next.y = 0  # Keep movement horizontal
	
	var distance_to_next = direction_to_next.length()
	
	# Move towards next waypoint
	if distance_to_next > navigation_agent.path_desired_distance:
		direction_to_next = direction_to_next.normalized()
		
		# Calculate desired velocity
		var desired_velocity = direction_to_next * speed
		
		# Use navigation agent's avoidance system
		navigation_agent.set_velocity(desired_velocity)
	else:
		# Close to waypoint, slow down
		var slow_velocity = velocity * 0.5
		slow_velocity.y = 0
		navigation_agent.set_velocity(slow_velocity)

func _on_velocity_computed(safe_velocity: Vector3):
	"""Handle the velocity computed by navigation agent"""
	# Apply the safe velocity
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z
	
	# Rotate to face movement direction
	if safe_velocity.length() > 0.1:
		var look_direction = Vector3(safe_velocity.x, 0, safe_velocity.z).normalized()
		var look_target = global_position + look_direction
		var target_transform = transform.looking_at(look_target, Vector3.UP)
		transform = transform.interpolate_with(target_transform, 4.0 * get_physics_process_delta_time())

func _on_navigation_finished():
	"""Called when navigation can't find a path to target"""
	print("Navigation finished - no path to target")
	
	# Try to get a new path after a short delay
	await get_tree().create_timer(0.5).timeout
	if target and navigation_ready:
		update_navigation_target()

func _on_target_reached():
	"""Called when we reach the navigation target"""
	print("Target reached!")
	
	# Wait a moment then try to get closer or update target
	await get_tree().create_timer(0.3).timeout
	if target and navigation_ready:
		update_navigation_target()

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

# Debug function
func _input(event):
	if event.is_action_pressed("ui_accept"):
		print("=== ENEMY DEBUG ===")
		print("Position: ", global_position)
		print("Target: ", target.global_position if target else "None")
		print("Velocity: ", velocity)
		print("Navigation ready: ", navigation_ready)
		print("Position history size: ", position_history.size())
		
		if navigation_agent:
			print("Nav target: ", navigation_agent.target_position)
			print("Nav finished: ", navigation_agent.is_navigation_finished())
			print("Nav map valid: ", navigation_agent.get_navigation_map().is_valid())
			print("Distance to player: ", global_position.distance_to(target.global_position) if target else "N/A")
			
			if navigation_agent.get_navigation_map().is_valid():
				var nav_map = navigation_agent.get_navigation_map()
				var closest = NavigationServer3D.map_get_closest_point(nav_map, global_position)
				print("Closest nav point: ", closest)
				print("Distance to nav mesh: ", global_position.distance_to(closest))
		print("===================")
