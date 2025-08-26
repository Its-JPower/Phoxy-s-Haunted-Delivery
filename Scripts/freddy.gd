extends CharacterBody3D

@onready var footstep_timer: Timer = $FootstepTimer
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var anim_player: AnimationPlayer = $Freddy/AnimationPlayer
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

@export var speed = 6.0  # Faster when not observed
@export var gravity = -20.0
@export var vision_check_distance = 50.0  # How far to check for player vision
@export var freeze_when_observed = true

var target: CharacterBody3D
var navigation_ready = false
var is_being_observed = false
var player_camera: Camera3D

# Visual feedback
var statue_material: Material
var normal_material: Material

func _ready():
	add_to_group("Enemies")
	print("Weeping Angel spawned at position: ", global_position)
	
	if navigation_agent:
		navigation_agent.radius = 0.4
		navigation_agent.height = 2.0
		navigation_agent.path_desired_distance = 0.8
		navigation_agent.target_desired_distance = 2.0
		navigation_agent.avoidance_enabled = false
		print("Navigation agent configured")
	
	call_deferred("setup_navigation")

func setup_navigation():
	await get_tree().create_timer(2.0).timeout
	
	target = get_tree().get_first_node_in_group("Player")
	if not target:
		print("ERROR: No player found!")
		return
	
	# Find player's camera
	player_camera = target.get_node("CameraController/Camera3D")  # Adjust path as needed
	if not player_camera:
		print("WARNING: No player camera found for vision detection")
	
	print("Weeping Angel targeting player at: ", target.global_position)
	navigation_ready = true
	update_target()

func _physics_process(delta):
	if Global.freeze:
		handle_freeze()
		return
	else:
		handle_unfreeze()
	
	if not navigation_ready or not target:
		return
	
	# Check if being observed by player
	check_if_observed()
	
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0
	
	# Only move if not being observed
	if not is_being_observed:
		update_target()
		navigate_to_target()
	else:
		# Freeze in place when observed
		velocity.x = 0
		velocity.z = 0
		# Play statue pose animation
		if anim_player and anim_player.current_animation != "statue_pose":
			anim_player.play("statue_pose")  # You'll need to create this animation
	
	move_and_slide()
	
	# Only play footsteps when moving and not observed
	if not is_being_observed:
		handle_footsteps()

func check_if_observed():
	if not player_camera or not target:
		is_being_observed = false
		return
	
	var was_observed = is_being_observed
	is_being_observed = false
	
	# Check distance first
	var distance_to_player = global_position.distance_to(target.global_position)
	if distance_to_player > vision_check_distance:
		update_visual_state(was_observed)
		return
	
	# Check if enemy is in camera's view frustum
	if is_in_camera_view():
		# Check if there's line of sight (no walls blocking)
		if has_line_of_sight_to_player():
			is_being_observed = true
	
	update_visual_state(was_observed)

func is_in_camera_view() -> bool:
	if not player_camera:
		return false
	
	# Get camera's transform
	var camera_transform = player_camera.global_transform
	var camera_pos = camera_transform.origin
	var camera_forward = -camera_transform.basis.z
	
	# Vector from camera to enemy
	var to_enemy = (global_position - camera_pos).normalized()
	
	# Check if enemy is in front of camera
	var dot_product = camera_forward.dot(to_enemy)
	if dot_product < 0.3:  # Roughly 70-degree field of view
		return false
	
	# Use camera's built-in frustum check for more accuracy
	var enemy_aabb = AABB(global_position - Vector3.ONE, Vector3.ONE * 2)
	return player_camera.is_position_in_frustum(global_position)

func has_line_of_sight_to_player() -> bool:
	if not target:
		return false
	
	var space_state = get_world_3d().direct_space_state
	var from = global_position + Vector3(0, 1.0, 0)  # Enemy eye level
	var to = target.global_position + Vector3(0, 1.0, 0)  # Player eye level
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Wall collision layer
	query.exclude = [self, target]
	
	var result = space_state.intersect_ray(query)
	return result.is_empty()  # True if no walls blocking

func update_visual_state(was_observed: bool):
	# Change appearance when observed/not observed
	if is_being_observed != was_observed:
		if is_being_observed:
			print("Weeping Angel frozen - being observed!")
			# Change to statue material/pose
			apply_statue_appearance()
		else:
			print("Weeping Angel free to move")
			# Change back to normal appearance
			apply_normal_appearance()

func apply_statue_appearance():
	# Change material to stone-like appearance
	var mesh_instance = $Freddy/MeshInstance3D  # Adjust path
	if mesh_instance and statue_material:
		mesh_instance.set_surface_override_material(0, statue_material)
	
	# Stop movement animations
	if anim_player:
		anim_player.play("statue_pose")

func apply_normal_appearance():
	# Restore normal material
	var mesh_instance = $Freddy/MeshInstance3D  # Adjust path
	if mesh_instance:
		mesh_instance.set_surface_override_material(0, normal_material)
	
	# Resume normal animations
	if anim_player:
		anim_player.play("walk")  # Or whatever your normal animation is

func update_target():
	if not navigation_agent or not target:
		return
	
	navigation_agent.target_position = target.global_position

func navigate_to_target():
	if not navigation_agent:
		return
	
	if navigation_agent.is_navigation_finished():
		velocity.x = 0
		velocity.z = 0
		return
	
	var next_position = navigation_agent.get_next_path_position()
	var direction = (next_position - global_position).normalized()
	direction.y = 0
	
	# Move faster when not observed
	var current_speed = speed
	if is_being_observed:
		current_speed = 0  # Completely stop when observed
	
	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed
	
	# Face movement direction (only when moving)
	if direction.length() > 0.1 and not is_being_observed:
		var look_target = global_position + direction
		look_at(look_target, Vector3.UP)

func handle_freeze():
	if anim_player and anim_player.is_playing():
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
	if anim_player and not anim_player.is_playing() and not is_being_observed:
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
