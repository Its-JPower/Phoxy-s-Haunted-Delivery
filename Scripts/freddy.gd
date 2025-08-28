extends CharacterBody3D

@onready var footstep_timer: Timer = $FootstepTimer
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var anim_player: AnimationPlayer = $Freddy/AnimationPlayer
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

@export var speed = 8.0  # Faster when not observed
@export var gravity = -20.0
@export var vision_check_distance = 50.0  # How far to check for player vision
@export var freeze_when_observed = true
@export var mass = 10.0  # Make enemy heavier so player can't push easily
@export var min_freeze_distance = 0.5  # Always freeze when this close to player

var target: CharacterBody3D
var navigation_ready = false
var is_being_observed = false
var player_camera: Camera3D

# Animation state tracking
var was_animation_playing = false
var current_animation_position = 0.0
var paused_animation_name = ""

# Visual feedback
var statue_material: Material
var normal_material: Material

func _ready():
	add_to_group("Enemies")
	print("Weeping Angel spawned at position: ", global_position)
	
	# Set up physics properties to prevent pushing
	set_collision_layer(2)  # Enemy layer
	set_collision_mask(1)   # Collide with walls/environment only, not player
	
	# Make the enemy much heavier and more stable
	if has_method("set_mass"):
		call("set_mass", mass)
	
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
	var was_observed = is_being_observed
	check_if_observed()
	
	# Handle animation state changes when observation status changes
	if was_observed != is_being_observed:
		handle_observation_change(was_observed)
	
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
		# Freeze in place when observed - resist all movement
		velocity.x = 0
		velocity.z = 0
		# Add resistance to external forces when frozen
		if has_method("set_lock_rotation_enabled"):
			call("set_lock_rotation_enabled", true)
	
	move_and_slide()
	
	# Resist being pushed by adding counter-force when frozen
	if is_being_observed and get_slide_collision_count() > 0:
		resist_pushing()
	
	# Only play footsteps when moving and not observed
	if not is_being_observed:
		handle_footsteps()

func handle_observation_change(was_observed: bool):
	"""Handle the transition between observed and not observed states"""
	if is_being_observed and not was_observed:
		# Just became observed - freeze animations
		freeze_animations()
	elif not is_being_observed and was_observed:
		# Just became unobserved - resume animations
		resume_animations()

func freeze_animations():
	"""Freeze all animations when being observed"""
	if anim_player and anim_player.is_playing():
		# Store current animation state
		was_animation_playing = true
		paused_animation_name = anim_player.current_animation
		current_animation_position = anim_player.current_animation_position
		
		# Pause the animation
		anim_player.pause()
		print("Animation paused: ", paused_animation_name, " at position: ", current_animation_position)
	
	# Stop footstep timer
	if footstep_timer and not footstep_timer.is_stopped():
		footstep_timer.paused = true
	
	# Pause audio if playing
	if audio_player and audio_player.playing:
		audio_player.stream_paused = true

func resume_animations():
	"""Resume animations when no longer being observed"""
	if anim_player and was_animation_playing:
		# Resume the paused animation from where it left off
		if paused_animation_name != "":
			anim_player.play(paused_animation_name)
			anim_player.seek(current_animation_position, true)
			print("Animation resumed: ", paused_animation_name, " from position: ", current_animation_position)
		
		was_animation_playing = false
		paused_animation_name = ""
		current_animation_position = 0.0
	
	# Resume footstep timer
	if footstep_timer:
		footstep_timer.paused = false
	
	# Resume audio
	if audio_player:
		audio_player.stream_paused = false

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
	
	# Always freeze when very close to player (they can definitely see you)
	if distance_to_player <= min_freeze_distance:
		is_being_observed = true
		print("Weeping Angel frozen - too close to player! Distance: ", distance_to_player)
		update_visual_state(was_observed)
		return
	
	# Check if enemy is in camera's view frustum
	if is_in_camera_view():
		# Check if there's line of sight (no walls blocking)
		if has_line_of_sight_to_player():
			is_being_observed = true
			print("Weeping Angel frozen - in camera view with line of sight! Distance: ", distance_to_player)
	
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
	
	# Check if enemy is in front of camera (more generous field of view)
	var dot_product = camera_forward.dot(to_enemy)
	if dot_product < 0.1:  # Very wide field of view - almost 180 degrees
		return false
	
	# Additional check: if enemy is very close, they're definitely visible
	var distance = camera_pos.distance_to(global_position)
	if distance < min_freeze_distance * 2:
		return true
	
	# Use camera's built-in frustum check for accuracy
	return player_camera.is_position_in_frustum(global_position)

func has_line_of_sight_to_player() -> bool:
	if not target:
		return false
	
	var space_state = get_world_3d().direct_space_state
	var from = global_position + Vector3(0, 1.0, 0)  # Enemy eye level
	var to = target.global_position + Vector3(0, 1.0, 0)  # Player eye level
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Wall collision layer only
	query.exclude = [self, target]  # Exclude both enemy and player from ray
	
	var result = space_state.intersect_ray(query)
	var has_clear_sight = result.is_empty()
	
	if not has_clear_sight and result.has("collider"):
		print("Line of sight blocked by: ", result.collider.name)
	
	return has_clear_sight  # True if no walls blocking

func resist_pushing():
	"""Resist being pushed when frozen by applying counter-forces"""
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# If colliding with player, resist the push
		if collider and collider.is_in_group("Player"):
			var push_force = collision.get_normal() * -500  # Strong resistance
			# Apply counter-force to maintain position
			velocity += push_force * get_physics_process_delta_time()
			print("Resisting player push!")

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

func apply_normal_appearance():
	# Restore normal material
	var mesh_instance = $Freddy/MeshInstance3D  # Adjust path
	if mesh_instance:
		mesh_instance.set_surface_override_material(0, normal_material)
	
	# Start appropriate movement animation if not already playing
	if anim_player and velocity.length() > 0.5 and not anim_player.is_playing():
		anim_player.play("walk")  # Or whatever your movement animation is

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
		
		# Play walking animation if not already playing and not observed
		if anim_player and anim_player.current_animation != "walk" and not is_being_observed:
			anim_player.play("walk")

func handle_freeze():
	# Global freeze handling (different from observation freeze)
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
	# Global unfreeze handling
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
