extends CharacterBody3D

@onready var nav_agent = $NavigationAgent3D
@onready var TARGET : CharacterBody3D = get_tree().get_first_node_in_group("Player")

@export var SPEED = 7.5

func _physics_process(delta: float) -> void:
	var current_location = global_transform.origin
	var next_location = nav_agent.get_next_path_position()
	var direction = (next_location - current_location).normalized()
	velocity = direction * SPEED
	move_and_slide()

var last_target_position = Vector3.ZERO

func update_target_location(target_location):
	if last_target_position.distance_to(target_location) > 0.5:
		nav_agent.set_target_position(target_location)
		last_target_position = target_location
