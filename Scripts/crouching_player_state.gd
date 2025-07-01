class_name CrouchingPlayerState extends PlayerMovementState

@export var SPEED: float = 3.0
@export var ACCELERATION: float = 0.1
@export var DECELERATION: float = 0.25
@export_range(1,6,0.6) var CROUCH_SPEED: float = 4.0

@onready var CROUCH_SHAPECAST: ShapeCast3D = %ShapeCast3D

var RELEASED : bool = false

func enter(previous_state) -> void:
	ANIMATION.speed_scale = 1.0
	if previous_state.name != "SlidingPlayerState":
		ANIMATION.play("crouch", -1.0, CROUCH_SPEED)
	else:
		ANIMATION.play("crouch")
		ANIMATION.seek(1, true) # Start *almost* crouched to match slide end
		# Optional: use a blend time

func exit() -> void:
	RELEASED = false

func update(delta):
	PLAYER.update_gravity(delta)
	PLAYER.update_input(SPEED,ACCELERATION,DECELERATION)
	PLAYER.update_velocity()
	
	if Input.is_action_just_released("crouch"):
		uncrouch()
	if Input.is_action_pressed("crouch") == false and RELEASED == false:
		RELEASED = true
		uncrouch()

func uncrouch():
	if CROUCH_SHAPECAST.is_colliding() == false:
		ANIMATION.play("crouch", -1.0, -CROUCH_SPEED, true)
		await ANIMATION.animation_finished
		if PLAYER.velocity.length() == 0:
			transition.emit("IdlePlayerState")
		else:
			transition.emit("WalkingPlayerState")
	elif CROUCH_SHAPECAST.is_colliding() == true:
		await get_tree().create_timer(0.1).timeout
		uncrouch()
