extends Node3D

@export var ANIM_PLAYER : AnimationPlayer
@export var AUDIO_PLAYER : AudioStreamPlayer

@onready var LEVEL_START_AUDIO = preload("res://Assets/Audio/level_start.mp3")

func _ready() -> void:
	AUDIO_PLAYER.stream = LEVEL_START_AUDIO
	AUDIO_PLAYER.play(0.0)
