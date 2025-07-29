class_name WallRunPlayerState extends PlayerMovementState

@export var SPEED: float = 6.0
@export var ACCELERATION: float = 0.1
@export var DECELERATION: float = 0.25
@export var TILT_AMOUNT: float = 0.09
@export_range(1,6,0.1) var WALLRUN_ANIM_SPEED : float = 4.0

@onready var CROUCH_SHAPECAST : ShapeCast3D = %ShapeCast3D

var rotation_index

func _ready():
	super()
	await owner.ready
	rotation_index = ANIMATION.get_animation("WallRun").find_track("CameraController:rotation", Animation.TYPE_VALUE)

func enter(previous_state):
	PLAYER.GRAVITY = -5.0
	set_tilt(PLAYER._current_rotation)
	ANIMATION.speed_scale = 1.0
	ANIMATION.play("WallRun", -1.0, WALLRUN_ANIM_SPEED)

func update(delta):
	PLAYER.update_gravity(delta)
	PLAYER.update_input(SPEED*1.5,ACCELERATION,DECELERATION)
	PLAYER.update_velocity()
	if not PLAYER.is_on_wall() or PLAYER.is_on_floor():
		transition.emit("IdlePlayerState")

func set_tilt(player_rotation) -> void:
	var tilt = Vector3.ZERO
	tilt.z = clamp(TILT_AMOUNT * player_rotation, -0.1, 0.1)
	if tilt.z == 0.0:
		tilt.z = 0.05
	ANIMATION.get_animation("WallRun").track_set_key_value(rotation_index,1,tilt)
	ANIMATION.get_animation("WallRun").track_set_key_value(rotation_index,2,tilt)

func exit():
	ANIMATION.stop()
	PLAYER.GRAVITY = -11.0
	
	var tilt_reset := get_tree().create_tween()
	tilt_reset.tween_property(
		PLAYER.CAMERA_CONTROLLER,
		"rotation:z",
		0.0,
		0.8
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
