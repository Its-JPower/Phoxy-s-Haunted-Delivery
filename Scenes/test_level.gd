extends Node3D

@onready var maze_generator = $MazeGenerator3D
@export var player : CharacterBody3D
@export var ANIM_PLAYER : AnimationPlayer
@export var AUDIO_PLAYER : AudioStreamPlayer
@export var enemy_scene : PackedScene
@onready var LEVEL_START_AUDIO = preload("res://Assets/Audio/level_start.mp3")

func _ready():
	if not validate_setup():
		return
	
	print("Initializing level...")
	maze_generator.generate_maze()
	
	# Debug the maze structure around spawn
	maze_generator.debug_spawn_area()
	
	# Wait for navigation to be ready
	print("Waiting for navigation mesh...")
	await get_tree().create_timer(1.0).timeout
	
	# Check if navigation is actually ready
	var nav_region = maze_generator.get_navigation_region()
	if nav_region and nav_region.navigation_mesh and nav_region.navigation_mesh.get_vertices().size() > 0:
		print("Navigation mesh ready with ", nav_region.navigation_mesh.get_vertices().size(), " vertices")
	else:
		print("WARNING: Navigation mesh may not be ready!")
	
	await spawn_player()
	
	print("Attempting to spawn enemies...")
	var enemy_count = await spawn_enemies(1)
	print("Successfully spawned ", enemy_count, " enemies")
	
	spawn_enemies_in_secret_rooms()
	print("Level ready!")

func validate_setup() -> bool:
	if not maze_generator:
		print("ERROR: No maze generator!")
		return false
	if not player:
		print("ERROR: No player assigned!")
		return false
	if not enemy_scene:
		print("ERROR: No enemy scene assigned!")
		return false
	return true

func spawn_player():
	var spawn_pos = await maze_generator.get_guaranteed_safe_spawn_position()
	spawn_pos.y = 3.0  # Ensure player spawns 3 units above floor
	player.global_position = spawn_pos
	print("Player spawned at: ", spawn_pos)
	
	# Wait a moment and check final position
	await get_tree().create_timer(0.5).timeout
	print("Player position after settling: ", player.global_position)

func spawn_enemies(count: int) -> int:
	print("Getting safe enemy positions for ", count, " enemies...")
	var safe_positions = get_safe_enemy_positions(count)
	print("Found ", safe_positions.size(), " safe positions")
	
	if safe_positions.size() == 0:
		print("ERROR: No safe enemy spawn positions found!")
		# Try emergency spawn
		return await emergency_spawn_enemies(count)
	
	var spawned_count = 0
	for i in range(safe_positions.size()):
		var pos = safe_positions[i]
		print("Attempting to spawn enemy ", i + 1, " at ", pos)
		var success = await spawn_enemy_at(pos)
		if success:
			spawned_count += 1
		await get_tree().create_timer(0.1).timeout
	
	return spawned_count

func get_safe_enemy_positions(count: int) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	
	print("Getting enemy spawn positions...")
	
	# Just get all possible positions and filter by distance
	var all_positions = maze_generator.get_possible_spawn_positions()
	print("Found ", all_positions.size(), " total possible positions")
	
	# Sort positions by distance from player (farthest first)
	var positions_with_distance = []
	for world_pos in all_positions:
		if player:
			var distance = world_pos.distance_to(player.global_position)
			positions_with_distance.append({"pos": world_pos, "distance": distance})
	
	# Sort by distance (farthest first)
	positions_with_distance.sort_custom(func(a, b): return a.distance > b.distance)
	
	print("Checking positions from farthest to nearest...")
	
	# Take the farthest positions that are reasonable
	for item in positions_with_distance:
		var world_pos = item.pos
		var distance = item.distance
		
		# Only consider positions that are reasonably far
		if distance < 15.0:  # Must be at least 15 units away
			print("Position too close: ", world_pos, " distance: ", distance)
			continue
		
		# Skip if too close to existing enemies
		var too_close_to_enemy = false
		for existing in positions:
			if world_pos.distance_to(existing) < 8.0:
				too_close_to_enemy = true
				break
		if too_close_to_enemy:
			continue
		
		print("Accepting position: ", world_pos, " distance from player: ", distance)
		positions.append(world_pos)
		
		if positions.size() >= count:
			break
	
	# If no positions found, try with smaller distance requirement
	if positions.size() == 0:
		print("No far positions found, trying with smaller distance...")
		for item in positions_with_distance:
			var world_pos = item.pos
			var distance = item.distance
			
			if distance < 8.0:  # At least 8 units away
				continue
			
			print("Accepting backup position: ", world_pos, " distance: ", distance)
			positions.append(world_pos)
			
			if positions.size() >= count:
				break
	
	print("Final enemy positions: ", positions.size(), " found")
	return positions

func emergency_spawn_enemies(count: int) -> int:
	print("Attempting emergency enemy spawn...")
	if not player:
		print("No player for emergency spawn!")
		return 0
	
	var spawned_count = 0
	for i in range(count):
		# Spawn near player but offset
		var offset = Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
		var spawn_pos = player.global_position + offset
		spawn_pos.y = 3.0
		
		print("Emergency spawn attempt at: ", spawn_pos)
		var success = await spawn_enemy_at(spawn_pos)
		if success:
			spawned_count += 1
	
	return spawned_count

func spawn_enemy_at(world_pos: Vector3) -> bool:
	print("spawn_enemy_at called with position: ", world_pos)
	
	if not enemy_scene:
		print("ERROR: enemy_scene is null!")
		return false
	
	print("Instantiating enemy scene...")
	var enemy = enemy_scene.instantiate()
	if not enemy:
		print("ERROR: Failed to instantiate enemy scene!")
		return false
	
	print("Enemy instantiated successfully, type: ", enemy.get_class())
	
	# Use the position directly (it's already been validated)
	world_pos.y = 3.0  # Ensure proper spawn height
	
	print("Setting enemy position to: ", world_pos)
	enemy.global_position = world_pos
	enemy.add_to_group("Enemies")
	
	print("Adding enemy to scene tree...")
	add_child(enemy)
	
	# Verify enemy was added
	var enemies_in_scene = get_tree().get_nodes_in_group("Enemies")
	print("Enemies in scene after adding: ", enemies_in_scene.size())
	
	await get_tree().process_frame
	
	# Check enemy position after physics frame
	print("Enemy position after physics frame: ", enemy.global_position)
	
	# Configure navigation if enemy has NavigationAgent3D
	var nav_agent = enemy.get_node_or_null("NavigationAgent3D")
	if nav_agent:
		print("Configuring enemy navigation agent...")
		await maze_generator.setup_navigation_agent_for_maze(nav_agent)
		
		# Set initial target to player
		if player:
			nav_agent.target_position = player.global_position
			print("Set enemy target to player position: ", player.global_position)
	else:
		print("WARNING: Enemy has no NavigationAgent3D node!")
	
	print("Enemy spawned successfully at: ", world_pos)
	return true

func spawn_enemies_in_secret_rooms():
	if not enemy_scene:
		return
	
	var secret_rooms = maze_generator.get_secret_room_positions()
	for room_pos in secret_rooms:
		var world_pos = maze_generator.grid_to_world(room_pos) + Vector3(0, 3.0, 0)
		await spawn_enemy_at(world_pos)

# Debug controls
func _input(event):
	if event.is_action_pressed("ui_page_up"):
		debug_level()
	elif event.is_action_pressed("ui_page_down"):
		respawn_enemies()

func debug_level():
	print("=== LEVEL DEBUG ===")
	print("Player: ", player.global_position if player else "None")
	print("Enemies: ", get_tree().get_nodes_in_group("Enemies").size())
	
	# Debug spawn area
	maze_generator.debug_spawn_area()
	
	# Debug navigation
	maze_generator.debug_navigation_setup()
	
	# Test if player position is safe
	if player:
		var player_2d = Vector2(player.global_position.x, player.global_position.z)
		var spawn_world_2d = Vector2(maze_generator.grid_to_world(Vector2i(1, 1)).x, maze_generator.grid_to_world(Vector2i(1, 1)).z)
		print("Player 2D distance from expected spawn: ", player_2d.distance_to(spawn_world_2d))

func respawn_enemies():
	# Remove existing enemies
	var enemies = get_tree().get_nodes_in_group("Enemies")
	for enemy in enemies:
		enemy.queue_free()
	await get_tree().process_frame
	# Respawn
	await spawn_enemies(1)
