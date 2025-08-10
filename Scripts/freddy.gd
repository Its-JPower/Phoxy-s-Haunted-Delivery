extends CharacterBody3D

@onready var nav_agent = $NavigationAgent3D
@onready var TARGET : CharacterBody3D = get_tree().get_first_node_in_group("Player")

@export var SPEED = 8
@onready var FOOTSTEP_TIMER: Timer = $FootstepTimer
@onready var AUDIO_PLAYER: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var ANIM_PLAYER: AnimationPlayer = $Freddy/AnimationPlayer


func _physics_process(delta: float) -> void:
	if Global.freeze:
		ANIM_PLAYER.pause()
		velocity = Vector3.ZERO
		move_and_slide()

		AUDIO_PLAYER.stream_paused = true
		FOOTSTEP_TIMER.paused = true
		return
	else:
		ANIM_PLAYER.play()
		AUDIO_PLAYER.stream_paused = false
		FOOTSTEP_TIMER.paused = false

	var current_location = global_transform.origin
	var next_location = nav_agent.get_next_path_position()
	var direction = (next_location - current_location).normalized()

	if direction.length() > 0.1:
		var target_position = Vector3(
			TARGET.global_position.x,
			global_position.y,
			TARGET.global_position.z
		)
		look_at(target_position)

	velocity = direction * SPEED
	move_and_slide()

	if velocity.length() > 0:
		if FOOTSTEP_TIMER.time_left <= 0:
			AUDIO_PLAYER.pitch_scale = randf_range(0.8, 1.2)
			AUDIO_PLAYER.play()
			FOOTSTEP_TIMER.start(0.85)



func update_target_location(target_location):
	nav_agent.set_target_position(target_location)

func _on_player_detection_area_entered(area: Area3D) -> void:
	if area.is_in_group("Player"):
		area.initiate_jumpscare(self)
