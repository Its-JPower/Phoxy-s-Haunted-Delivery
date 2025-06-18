extends VBoxContainer

@onready var btn_play: Button = $btn_play
@onready var btn_options: Button = $btn_options
@onready var btn_quit: Button = $btn_quit

func _ready() -> void:
	pass # Replace with function body.

func _process(delta: float) -> void:
	pass

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://addons/Map/TemplateMapScene.tscn")

func _on_options_pressed() -> void:
	pass # Replace with function body.


func _on_quit_pressed() -> void:
	get_tree().quit()
