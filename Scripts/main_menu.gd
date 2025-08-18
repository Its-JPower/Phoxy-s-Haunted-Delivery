extends CanvasLayer

@onready var foxy_anim: AnimationPlayer = $Background/Foxy/AnimationPlayer
@onready var camera: Camera3D = $Background/SubViewportContainer/SubViewport/Node3D/Camera3D
@onready var btn_play: Button = $Menu/MarginContainer/VBoxContainer/btn_play
@onready var btn_options: Button = $Menu/MarginContainer/VBoxContainer/btn_options
@onready var btn_quit: Button = $Menu/MarginContainer/VBoxContainer/btn_quit
@onready var audio_player: AudioStreamPlayer = $Menu/MarginContainer/VBoxContainer/audio_player

var rotation_speed = .125


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	foxy_anim.play("idle", .25, 0.06125)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	camera.rotate_y(rotation_speed * delta)


#region UI Buttons


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/test_level.tscn")

func _on_options_pressed() -> void:
	pass # Replace with function body.

func _on_quit_pressed() -> void:
	get_tree().quit(1)

func play_audio():
	audio_player.stream = preload("res://Assets/Audio/btn_hover.mp3")
	audio_player.play()

#region UI Buttons Hovered

func _on_btn_play_mouse_entered() -> void:
	btn_play.add_theme_font_size_override("font_size", 36)
	play_audio()
func _on_btn_play_mouse_exited() -> void:
	btn_play.remove_theme_font_size_override("font_size")
func _on_btn_options_mouse_entered() -> void:
	btn_options.add_theme_font_size_override("font_size", 36)
	play_audio()
func _on_btn_options_mouse_exited() -> void:
	btn_options.remove_theme_font_size_override("font_size")
func _on_btn_quit_mouse_entered() -> void:
	btn_quit.add_theme_font_size_override("font_size", 36)
	play_audio()
func _on_btn_quit_mouse_exited() -> void:
	btn_quit.remove_theme_font_size_override("font_size")
	
#endregion

#endregion
