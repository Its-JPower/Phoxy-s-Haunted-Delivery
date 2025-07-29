extends Node3D

@onready var PLAYER = get_tree().get_first_node_in_group("Player")

func _physics_process(delta: float) -> void:
	get_tree().call_group("Enemies","update_target_location",PLAYER.global_transform.origin)
