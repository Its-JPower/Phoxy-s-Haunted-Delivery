extends Node3D

@onready var maze_generator = $MazeGenerator3D
@export var player : CharacterBody3D
@export var ANIM_PLAYER : AnimationPlayer
@export var AUDIO_PLAYER : AudioStreamPlayer
@export var enemy_scene : PackedScene
@onready var LEVEL_START_AUDIO = preload("res://Assets/Audio/level_start.mp3")

# Cached values for optimization
var _spawn_positions_cache: Array[Vector3] = []
var _enemies_spawned: int = 0

func _ready():
	if not validate_setup():
		return
	
	print("Initializing level...")
	maze_generator.generate_maze()
	
	# Wait for navigation to be ready
	await wait_for_navigation()
	
	# Spawn everything
	await spawn_player()
	await spawn_initial_enemies()
	spawn_secret_room_enemies()
	
	print("Level ready! Enemies spawned: ", _enemies_spawned)

func validate_setup() -> bool:
	var issues = []
	if not maze_generator: issues.append("No maze generator")
	if not player: issues.append("No player assigned")
	if not enemy_scene: issues.append("No enemy scene assigned")
	
	if issues.size() > 0:
		print("ERROR: Setup validation failed: ", ", ".join(issues))
		return false
	return true

func wait_for_navigation():
	print("Waiting for navigation mesh...")
	var max_wait_time = 3.0
	var wait_time = 0.0
	var check_interval = 0.1
	
	while wait_time < max_wait_time:
		await get_tree().create_timer(check_interval).timeout
		wait_time += check_interval
		
		var nav_region = maze_generator.get_navigation_region()
		if nav_region and nav_region.navigation_mesh and nav_region.navigation_mesh.get_vertices().size() > 0:
			print("Navigation mesh ready with ", nav_region.navigation_mesh.get_vertices().size(), " vertices")
			return
	
	print("WARNING: Navigation mesh not ready after ", max_wait_time, " seconds!")

func spawn_player():
	var spawn_pos = maze_generator.get_player_spawn_position()
	player.global_position = spawn_pos
	print("Player spawned at: ", spawn_pos)
	
	# Cache spawn positions for enemies after player is positioned
	_spawn_positions_cache = maze_generator.get_possible_spawn_positions()
	print("Cached ", _spawn_positions_cache.size(), " possible enemy spawn positions")

func spawn_enemies_optimized(count: int) -> int:
	if _spawn_positions_cache.is_empty():
		print("ERROR: No cached spawn positions available!")
		return await emergency_spawn_enemies(count)
	
	var suitable_positions = get_suitable_enemy_positions(count)
	if suitable_positions.is_empty():
		print("No suitable positions found, trying emergency spawn")
		return await emergency_spawn_enemies(count)
	
	var spawned_count = 0
	for position in suitable_positions:
		if await spawn_enemy_at_position(position):
			spawned_count += 1
	
	return spawned_count

func is_too_close_to_existing(pos: Vector3, existing_positions: Array[Vector3], min_distance: float) -> bool:
	for existing_pos in existing_positions:
		if pos.distance_to(existing_pos) < min_distance:
			return true
	return false

func spawn_enemy_at_position(world_pos: Vector3) -> bool:
	if not enemy_scene:
		print("ERROR: No enemy scene available")
		return false
	
	var enemy = enemy_scene.instantiate()
	if not enemy:
		print("ERROR: Failed to instantiate enemy")
		return false
	
	# Ensure proper spawn height
	world_pos.y = 3.0
	enemy.global_position = world_pos
	enemy.add_to_group("Enemies")
	add_child(enemy)
	
	# Wait for enemy to settle in scene
	await get_tree().process_frame
	
	# Configure navigation
	configure_enemy_navigation(enemy)
	
	return true

func emergency_spawn_enemies(count: int) -> int:
	print("Emergency enemy spawn for ", count, " enemies")
	if not player:
		return 0
	
	var spawned_count = 0
	var player_pos = player.global_position
	
	for i in range(count):
		# Create spawn position in a circle around player
		var angle = (float(i) / count) * TAU
		var distance = 10.0 + randf() * 5.0  # 10-15 units away
		var offset = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var spawn_pos = player_pos + offset
		spawn_pos.y = 3.0
		
		if await spawn_enemy_at_position(spawn_pos):
			spawned_count += 1
	
	return spawned_count

func spawn_secret_room_enemies():
	var secret_rooms = maze_generator.get_secret_room_positions()
	var spawned_in_secrets = 0
	
	for room_pos in secret_rooms:
		var world_pos = maze_generator.grid_to_world(room_pos) + Vector3(0, 3.0, 0)
		if await spawn_enemy_at_position(world_pos):
			spawned_in_secrets += 1
	
	_enemies_spawned += spawned_in_secrets
	print("Spawned ", spawned_in_secrets, " enemies in secret rooms")

# Optimized debug controls
func _input(event):
	if event.is_action_pressed("ui_page_up"):
		debug_level()
	elif event.is_action_pressed("ui_page_down"):
		respawn_all_enemies()
	elif event.is_action_pressed("ui_home"):
		teleport_player_to_spawn()
	elif event.is_action_pressed("ui_end"):  # Add this
		test_navigation_manually()
	if not event.is_pressed():
		return
	
	if event.is_action("ui_page_up"):
		debug_level()
	elif event.is_action("ui_page_down"):
		respawn_all_enemies()
	elif event.is_action("ui_home"):  # Additional debug key
		teleport_player_to_spawn()

func debug_level():
	print("=== LEVEL DEBUG ===")
	print("Player: ", player.global_position if player else "None")
	
	var enemies = get_tree().get_nodes_in_group("Enemies")
	print("Enemies: ", enemies.size())
	
	if player:
		var expected_spawn = maze_generator.get_player_spawn_position()
		var distance_from_spawn = player.global_position.distance_to(expected_spawn)
		print("Player distance from expected spawn: ", distance_from_spawn)
	
	# Test navigation
	var nav_region = maze_generator.get_navigation_region()
	if nav_region and nav_region.navigation_mesh:
		print("Navigation vertices: ", nav_region.navigation_mesh.get_vertices().size())
		print("Navigation polygons: ", nav_region.navigation_mesh.get_polygon_count())
	else:
		print("WARNING: No navigation mesh found!")
	
	# Test enemy positions
	for i in range(min(3, enemies.size())):
		var enemy = enemies[i]
		var nav_agent = enemy.get_node_or_null("NavigationAgent3D")
		if nav_agent:
			print("Enemy ", i, " at ", enemy.global_position, " target: ", nav_agent.target_position)

func respawn_all_enemies():
	print("Respawning all enemies...")
	
	# Remove existing enemies
	var enemies = get_tree().get_nodes_in_group("Enemies")
	for enemy in enemies:
		enemy.queue_free()
	
	await get_tree().process_frame
	_enemies_spawned = 0
	
	# Respawn
	await spawn_initial_enemies()
	spawn_secret_room_enemies()

func teleport_player_to_spawn():
	if player:
		var spawn_pos = maze_generator.get_player_spawn_position()
		player.global_position = spawn_pos
		print("Player teleported to spawn: ", spawn_pos)

# Utility functions for external access
func get_enemy_count() -> int:
	return get_tree().get_nodes_in_group("Enemies").size()

func get_player_position() -> Vector3:
	return player.global_position if player else Vector3.ZERO

func spawn_additional_enemy() -> bool:
	var positions = get_suitable_enemy_positions(1)
	if positions.size() > 0:
		return await spawn_enemy_at_position(positions[0])
	return false


# Key changes to make in your LevelManager.gd:

# 1. Make enemy count configurable (line 46):
@export var enemy_count: int = 3  # Now configurable in inspector

func spawn_initial_enemies():
	var spawned = await spawn_enemies_optimized(enemy_count)
	_enemies_spawned += spawned
	print("Spawned ", spawned, "/", enemy_count, " initial enemies")

# 2. Improve the enemy configuration (replace configure_enemy_navigation function):
func configure_enemy_navigation(enemy: Node3D):
	var nav_agent = enemy.get_node_or_null("NavigationAgent3D")
	if not nav_agent:
		return
	
	# Use the improved maze-specific setup
	if maze_generator.has_method("setup_navigation_agent_for_maze"):
		maze_generator.setup_navigation_agent_for_maze(nav_agent)
	else:
		# Fallback configuration
		nav_agent.radius = 0.3
		nav_agent.height = 2.0
		nav_agent.path_desired_distance = 0.2
		nav_agent.target_desired_distance = 0.8
		nav_agent.path_max_distance = 100.0
		nav_agent.avoidance_enabled = true
		nav_agent.neighbor_distance = 1.5
		nav_agent.max_neighbors = 2
		nav_agent.time_horizon = 1.0
	
	print("Configured navigation agent for enemy with radius: ", nav_agent.radius)

# 3. Improve enemy spawn positioning (replace get_suitable_enemy_positions):
func get_suitable_enemy_positions(count: int) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var player_pos = player.global_position
	
	# Get all possible positions and filter them better
	var all_positions = _spawn_positions_cache.duplicate()
	var suitable_positions: Array[Vector3] = []
	
	# First pass: find positions that meet basic requirements
	for pos in all_positions:
		var distance_to_player = pos.distance_to(player_pos)
		
		# Must be reasonably far from player but not too far
		if distance_to_player >= 8.0 and distance_to_player <= 40.0:
			suitable_positions.append(pos)
	
	if suitable_positions.is_empty():
		print("No suitable positions found, relaxing constraints...")
		# Fallback: accept closer positions
		for pos in all_positions:
			var distance_to_player = pos.distance_to(player_pos)
			if distance_to_player >= 5.0:
				suitable_positions.append(pos)
	
	# Sort by distance from player (farthest first for initial spawn)
	suitable_positions.sort_custom(func(a, b): return a.distance_to(player_pos) > b.distance_to(player_pos))
	
	# Select positions ensuring they're not too close to each other
	for pos in suitable_positions:
		if not is_too_close_to_existing(pos, positions, 6.0):
			positions.append(pos)
			if positions.size() >= count:
				break
	
	print("Selected ", positions.size(), " suitable enemy positions out of ", suitable_positions.size(), " candidates")
	return positions


func test_navigation_manually():
	print("=== MANUAL NAVIGATION TEST ===")
	if maze_generator:
		await maze_generator.debug_navigation_generation()
		print("Attempting to rebuild navigation...")
		await maze_generator.create_simple_navigation_mesh()
	print("==============================")
