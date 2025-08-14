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
	
	# Wait a moment for navigation to bake properly
	await get_tree().create_timer(0.5).timeout
	
	# Spawn player at safe position
	var spawn_pos = maze_generator.get_player_spawn_position()
	player.global_position = spawn_pos
	
	# Spawn enemies
	spawn_enemies(1)
	
	# Handle secret rooms (this was incomplete in your original)
	spawn_enemies_in_secret_rooms()

func _physics_process(delta: float) -> void:
	# Update enemy targets - but check if player exists first
	var player_node = get_tree().get_first_node_in_group("Player")
	if player_node:
		get_tree().call_group("Enemies", "update_target_location", player_node.global_position)

func spawn_enemies(count: int):
	# Check if enemy scene is assigned
	if not enemy_scene:
		print("ERROR: Enemy scene not assigned in inspector!")
		return
	
	var spawn_positions = maze_generator.get_possible_spawn_positions()
	
	if spawn_positions.size() == 0:
		print("No spawn positions available!")
		return
	
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
	
	print("Spawning enemy at: ", world_pos)
	
	enemy_instance.global_position = world_pos
	enemy_instance.add_to_group("Enemies")  # Fixed: was "Enemies" not "enemies" 
	add_child(enemy_instance)
	
	print("Enemy spawned successfully!")

func spawn_enemies_in_secret_rooms():
	if not enemy_scene:
		return
		
	var secret_rooms = maze_generator.get_secret_room_positions()
	for room_pos in secret_rooms:
		var world_pos = maze_generator.grid_to_world(room_pos)
		world_pos.y += 1  # Add height offset
		spawn_enemy_at_world_position(world_pos)
