extends CanvasLayer

@onready var foxy_anim: AnimationPlayer = $Background/Foxy/AnimationPlayer
@onready var camera: Camera3D = $Background/SubViewportContainer/SubViewport/Camera3D
@onready var tween = $Tween

var left_rotation = Vector3(0, deg_to_rad(-30), 0)
var right_rotation = Vector3(0, deg_to_rad(30), 0)
var going_right = true


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	foxy_anim.play("idle", .25, 0.25)
	pan_camera()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass




func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://addons/Map/TemplateMapScene.tscn")

func _on_options_pressed() -> void:
	pass # Replace with function body.

func _on_quit_pressed() -> void:
	get_tree().quit(1)

func pan_camera():
	var target_rotation = right_rotation if going_right else left_rotation
	tween.tween_property(camera, "rotation", target_rotation, 10.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	going_right = !going_right
	tween.finished.connect(pan_camera, CONNECT_ONE_SHOT)
