extends CharacterBody3D

@onready var nav_agent = $NavigationAgent3D
@onready var TARGET : CharacterBody3D = get_tree().get_first_node_in_group("Player")

@export var SPEED = 7.5

func _physics_process(delta: float) -> void:
	var current_location = global_transform.origin
	var next_location = nav_agent.get_next_location()
	var new_velocity = (next_location - current_location.normalized() * SPEED)
	
	velocity = new_velocity
	move_and_slide()

func update_target_location(target_location):
	nav_agent.set_target_location(target_location)
