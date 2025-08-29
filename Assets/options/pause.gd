extends Panel
@onready var click_sound := $Click
@onready var hover_sound := $Hover
@onready var settings : Panel = $Settings1/Settings
@onready var fade_rect := $FadeRect
@onready var pause_song := $Pause

func _ready():
	settings.visible = false
	fade_rect.color = Color.BLACK
	fade_rect.size = get_viewport().get_visible_rect().size
	fade_rect.modulate.a = 1.0
	# Wait a frame to ensure rendering is ready before fade-in
	await get_tree().process_frame
	# Fade in over 2.0 seconds
	var fade_in = create_tween()
	fade_in.tween_property(fade_rect, "modulate:a", 0.0, 2.0) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func fade_out_music() -> void:
	if pause_song.playing:
		var tween = create_tween()
		tween.tween_property(pause_song, "volume_db", -80.0, 3) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween.finished
		pause_song.stop()
		pause_song.volume_db = 0.0

func _on_resume_pressed() -> void:
	click_sound.play()
	await fade_out_music()
	# hide pause menu after fade-out
	self.visible = false
	get_tree().paused = false

func _on_quit_pressed() -> void:
	click_sound.play()
	await fade_out_music()
	var fade_out = create_tween()
	fade_out.tween_property(fade_rect, "modulate:a", 1.0, 1.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await fade_out.finished
	get_tree().change_scene_to_file("res://Scenes/Loading Screen/quit_loading_screen.tscn")
	print("Quit Pressed")

func _on_settings_pressed() -> void:
	click_sound.play()
	settings.visible = true
	print("Settings Pressed")

func _on_resume_mouse_entered() -> void:
	hover_sound.stop()
	hover_sound.play()

func _on_quit_mouse_entered() -> void:
	hover_sound.stop()
	hover_sound.play()

func _on_settings_mouse_entered() -> void:
	hover_sound.stop()
	hover_sound.play()

func _on_back_pressed() -> void:
	click_sound.play()
	settings.visible = false

func _on_restart_pressed() -> void:
	click_sound.play()
	
	# Clean up before restart to prevent camera bugs
	print("Restarting scene...")
	
	# Reset audio completely
	if pause_song.playing:
		pause_song.stop()
	
	# Reset mouse mode
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Unpause the game
	get_tree().paused = false
	
	# Get current scene path for fresh reload
	var current_scene_path = get_tree().current_scene.scene_file_path
	
	# Change to the scene fresh (this ensures complete reset)
	get_tree().change_scene_to_file(current_scene_path)

func _on_restart_mouse_entered() -> void:
	hover_sound.stop()
	hover_sound.play()
