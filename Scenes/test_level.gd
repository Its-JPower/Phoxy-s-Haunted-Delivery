extends Node3D

@onready var maze_generator = $MazeGenerator3D
@export var player : CharacterBody3D
@export var ANIM_PLAYER : AnimationPlayer
@export var AUDIO_PLAYER : AudioStreamPlayer
#@onready var timer: Timer = $Timer

@onready var LEVEL_START_AUDIO = preload("res://Assets/Audio/level_start.mp3")

func _ready():
#	AUDIO_PLAYER.stream = LEVEL_START_AUDIO
#	AUDIO_PLAYER.play(0.0)
	maze_generator.generate_maze()
	
	# Then spawn the player
	var spawn_pos = maze_generator.get_player_spawn_position()  # Safe default
	player.global_position = spawn_pos
	
	# Optional: Also spawn enemies in secret rooms
	var secret_rooms = maze_generator.get_secret_room_positions()
	for room_pos in secret_rooms:
		var world_pos = maze_generator.grid_to_world(room_pos)
#        spawn_enemy_at(world_pos)

func _physics_process(delta: float) -> void:
	get_tree().call_group("enemies", "update_target_location", get_tree().get_first_node_in_group("Player").global_transform.origin)
