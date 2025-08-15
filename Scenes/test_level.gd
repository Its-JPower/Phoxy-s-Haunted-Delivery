extends Node3D

@onready var maze_generator = $MazeGenerator3D
@export var player : CharacterBody3D
@export var ANIM_PLAYER : AnimationPlayer
@export var AUDIO_PLAYER : AudioStreamPlayer
@export var enemy_scene : PackedScene
@onready var LEVEL_START_AUDIO = preload("res://Assets/Audio/level_start.mp3")

func _ready():
	# Generate maze first
	maze_generator.generate_maze()
	
	# Wait longer for navigation to bake properly
	await get_tree().create_timer(1.0).timeout
	
	# Spawn player at safe position
	var spawn_pos = maze_generator.get_player_spawn_position()
	player.global_position = spawn_pos
	print("Player spawned at: ", spawn_pos)
	
	# Wait a bit more before spawning enemies
	await get_tree().create_timer(0.5).timeout
	
	# Spawn enemies
	spawn_enemies(1)
	
	# Handle secret rooms
	spawn_enemies_in_secret_rooms()

func spawn_enemies(count: int):
	# Check if enemy scene is assigned
	if not enemy_scene:
		print("ERROR: Enemy scene not assigned in inspector!")
		return
	
	var spawn_positions = maze_generator.get_possible_spawn_positions()
	
	if spawn_positions.size() == 0:
		print("No spawn positions available!")
		return
	
	# Get positions far from player for better gameplay
	var far_positions = maze_generator.get_positions_far_from_spawn(5.0)
	if far_positions.size() > 0:
		spawn_positions = []
		for pos in far_positions:
			spawn_positions.append(maze_generator.grid_to_world(pos) + Vector3(0, 1.5, 0))
	
	for i in range(min(count, spawn_positions.size())):
		var random_pos = spawn_positions[randi() % spawn_positions.size()]
		spawn_enemy_at_world_position(random_pos)
		spawn_positions.erase(random_pos)  # Don't spawn multiple at same spot

func spawn_enemy_at_world_position(world_pos: Vector3):
	if not enemy_scene:
		print("Enemy scene is null!")
		return
	
	var enemy_instance = enemy_scene.instantiate()
	
	if not enemy_instance:
		print("Failed to instantiate enemy!")
		return
	
	# Ensure proper spawn height
	world_pos.y = 1.5
	print("Spawning enemy at: ", world_pos)
	
	enemy_instance.global_position = world_pos
	enemy_instance.add_to_group("Enemies")
	add_child(enemy_instance)
	
	print("Enemy spawned successfully!")

func spawn_enemies_in_secret_rooms():
	if not enemy_scene:
		return
		
	var secret_rooms = maze_generator.get_secret_room_positions()
	for room_pos in secret_rooms:
		var world_pos = maze_generator.grid_to_world(room_pos)
		world_pos.y = 1.5  # Proper height offset
		spawn_enemy_at_world_position(world_pos)
