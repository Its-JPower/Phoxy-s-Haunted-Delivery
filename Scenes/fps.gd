extends Node3D

@onready var character: CharacterBody3D = $".."
@onready var foxy_2: Node3D = $"."

func _physics_process(delta: float) -> void:
	foxy_2.rotation = character.rotation
