class_name Player extends CharacterBody3D


@export var SPEED_DEFAULT : float = 5.0
@export var SPEED_SPRINTING : float = 7.0
@export var SPEED_CROUCH : float = 2.0
@export var ACCELERATION : float = 0.1
@export var DECELERATION : float = 0.25
@export var JUMP_VELOCITY : float = 4.5
@export_range(5,10,0.1) var CROUCH_SPEED : float = 7.0
@export var MOUSE_SENSITIVITY : float = 0.5
@export var TILT_LOWER_LIMIT := deg_to_rad(-90.0)
@export var TILT_UPPER_LIMIT := deg_to_rad(-90.0)
@export var CAMERA_CONTROLLER : Camera3D
@export var ANIMATION_PLAYER : AnimationPlayer
@export var FOXY_ANIMATION_PLAYER : AnimationPlayer
@export var CROUCH_SHAPECAST : ShapeCast3D
@export var GRAVITY : float = -11.0

var _speed : float
var _mouse_input : bool = false
var _mouse_rotation : Vector3
var _rotation_input : float
var _tilt_input : float
var _player_rotation : Vector3 
var _camera_rotation : Vector3
var _current_rotation : float
var _momentum: Vector3 = Vector3.ZERO

var wall_normal

var _is_crouching : bool = false

func _unhandled_input(event: InputEvent) -> void:
	_mouse_input = event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	if _mouse_input:
		_rotation_input = -event.relative.x * MOUSE_SENSITIVITY
		_tilt_input = -event.relative.y * MOUSE_SENSITIVITY

func _update_camera(delta):
	_current_rotation = _rotation_input
	_mouse_rotation.x += _tilt_input * delta
	_mouse_rotation.x = clamp(_mouse_rotation.x, TILT_LOWER_LIMIT, TILT_UPPER_LIMIT)
	_mouse_rotation.y += _rotation_input * delta
	
	_player_rotation = Vector3(0.0,_mouse_rotation.y,0.0)
	_camera_rotation = Vector3(_mouse_rotation.x,0.0,0.0)
	
	CAMERA_CONTROLLER.transform.basis = Basis.from_euler(_camera_rotation)
	CAMERA_CONTROLLER.rotation.z = 0.0
	
	global_transform.basis = Basis.from_euler(_player_rotation)
	
	_rotation_input = 0.0
	_tilt_input = 0.0

func _ready():
	
	Global.player = self
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_speed = SPEED_DEFAULT

	CROUCH_SHAPECAST.add_exception($".")

func _physics_process(delta: float) -> void:
	
	Global.debug.add_property("MouseRotation", _mouse_rotation, 2)
	Global.debug.add_property("Velocity", "%.2f" % velocity.length(), 3)	
	
	_update_camera(delta)
	
	if not is_on_floor():
		_momentum = _momentum.move_toward(Vector3.ZERO, DECELERATION * 0.5)

func update_gravity(delta) -> void:
	velocity.y += GRAVITY * delta

func update_input(speed: float, acceleration: float, deceleration: float) -> void:
	var input_dir = Input.get_vector("moveLeft", "moveRight", "moveForward", "moveBackward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var is_airborne = not is_on_floor()

	if is_airborne:
		if direction != Vector3.ZERO:
			_momentum = _momentum.lerp(direction * speed, acceleration * 0.3)
	else:
		if direction != Vector3.ZERO:
			_momentum = _momentum.lerp(direction * speed, acceleration)
		else:
			_momentum = _momentum.move_toward(Vector3.ZERO, deceleration)
	velocity.x = _momentum.x
	velocity.z = _momentum.z


func update_velocity() -> void:
	move_and_slide()
