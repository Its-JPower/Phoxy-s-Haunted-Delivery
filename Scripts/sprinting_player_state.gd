class_name SprintingPlayerState

extends PlayerMovementState

@export var SPEED: float = 7.0
@export var ACCELERATION: float = 0.1
@export var DECELERATION: float = 0.25
@export var TOP_ANIMATION_SPEED : float = 3
@export var FOOTSTEP_AUDIO_PLAYER: AudioStreamPlayer3D


@onready var FOOTSTEP_AUDIO1 = preload("res://Assets/Audio/footstep1.ogg")
@onready var FOOTSTEP_AUDIO2 = preload("res://Assets/Audio/footstep2.ogg")

func enter(previous_state) -> void:
	if ANIMATION.is_playing() and ANIMATION.current_animation == "JumpEnd":
		await ANIMATION.animation_finished
		ANIMATION.play("Walking",.5,1.0)
	else:
		ANIMATION.play("Walking",.5,1.0)

func update(delta):
	PLAYER.handle_stamina(delta)
	PLAYER.update_gravity(delta)
	PLAYER.update_input(SPEED, ACCELERATION, DECELERATION)
	PLAYER.update_velocity()
	
	#
	#if FOOTSTEP_AUDIO_PLAYER.playing == false:
		#FOOTSTEP_AUDIO_PLAYER.play(0.0)
	#await FOOTSTEP_AUDIO_PLAYER.finished
	#if FOOTSTEP_AUDIO_PLAYER.stream == FOOTSTEP_AUDIO1:
		#FOOTSTEP_AUDIO_PLAYER.stream = FOOTSTEP_AUDIO2
	#else:
		#FOOTSTEP_AUDIO_PLAYER.stream = FOOTSTEP_AUDIO1
	
	set_animation_speed(PLAYER._momentum.length())
	if Global.player.velocity.length() == 0.0 and Global.player.is_on_floor():
		transition.emit("IdlePlayerState")
	if Input.is_action_just_pressed("crouch") and PLAYER.velocity.length() > 6:
		transition.emit("SlidingPlayerState")
	if Input.is_action_just_pressed("jump") and PLAYER.is_on_floor():
		transition.emit("JumpingPlayerState")

func set_animation_speed(spd):
	var alpha = remap(spd, 0.0, SPEED, 0.0, 1.0)
	ANIMATION.speed_scale = lerp(0.0, TOP_ANIMATION_SPEED, alpha)
