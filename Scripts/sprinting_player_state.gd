class_name SprintingPlayerState

extends PlayerMovementState

@export var ANIMATION: AnimationPlayer
@export var TOP_ANIMATION_SPEED : float = 3

func enter() -> void:
	ANIMATION.play("Walking",.5,1.0)
	Global.player._speed = Global.player.SPEED_SPRINTING

func update(delta):
	set_animation_speed(Global.player.velocity.length())
	if Global.player.velocity.length() == 0.0 and Global.player.is_on_floor():
		transition.emit("IdlePlayerState")

func set_animation_speed(spd):
	var alpha = remap(spd, 0.0, Global.player.SPEED_SPRINTING, 0.0, 1.0)
	ANIMATION.speed_scale = lerp(0.0, TOP_ANIMATION_SPEED, alpha)

func _input(event) -> void:
	if event.is_action_released("sprint"):
		transition.emit("WalkingPlayerState")
