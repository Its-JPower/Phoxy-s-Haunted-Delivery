class_name JumpingPlayerState extends PlayerMovementState

@export var SPEED: float = 6.0
@export var ACCELERATION: float = 0.1
@export var DECELERATION: float = 0.25
@export var JUMP_VELOCITY: float = 4.5
@export var DOUBLE_JUMP_VELOCITY: float = 4.5
@export_range(0.5,1.0,0.1) var INPUT_MULTIPLIER : float = 0.85

var DOUBLE_JUMP: bool = false

func enter(previous_state) -> void:
	PLAYER.velocity.y += JUMP_VELOCITY
	ANIMATION.play("JumpStart")

func exit() -> void:
	DOUBLE_JUMP = false

func update(delta):
	PLAYER.update_gravity(delta)
	PLAYER.update_input(SPEED,ACCELERATION,DECELERATION)
	PLAYER.update_velocity()
	
	if Input.is_action_just_pressed("jump") and DOUBLE_JUMP == false:
		DOUBLE_JUMP = true
		PLAYER.velocity.y = DOUBLE_JUMP_VELOCITY
		
	if Input.is_action_just_released("jump"):
		if PLAYER.velocity.y > 0:
			PLAYER.velocity.y = PLAYER.velocity.y / 2.0
	
	#if Input.is_action_just_pressed("crouch") and not PLAYER.is_on_floor():
		#transition.emit("CrouchingPlayerState")
	
	if PLAYER.is_on_floor():
		transition.emit("IdlePlayerState")
	elif Input.is_action_pressed("jump") and Input.is_action_pressed("moveForward") and PLAYER.is_on_wall():
		transition.emit("WallRunPlayerState")
