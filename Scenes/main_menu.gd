extends CanvasLayer

@onready var foxy_anim: AnimationPlayer = $Background/Foxy/AnimationPlayer
@onready var camera: Camera3D = $Background/SubViewportContainer/SubViewport/Node3D/Camera3D
@onready var tween = $Twee


var rotation_speed = .125


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	foxy_anim.play("idle", .25, 0.125)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	camera.rotate_y(rotation_speed * delta)




func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://addons/Map/TemplateMapScene.tscn")

func _on_options_pressed() -> void:
	pass # Replace with function body.

func _on_quit_pressed() -> void:
	get_tree().quit(1)
