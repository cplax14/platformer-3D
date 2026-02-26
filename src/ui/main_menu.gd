extends Control

## Main menu — Play, Options, Quit.

@onready var options_scene := preload("res://src/ui/options_menu.tscn")

var _options_instance: Control = null


func _ready() -> void:
	get_tree().paused = false
	AudioManager.play_music(MusicLibrary.menu)


func _on_play_pressed() -> void:
	SaveManager.load_game()
	SceneTransition.transition_to_scene("res://src/ui/level_select.tscn")


func _on_options_pressed() -> void:
	if _options_instance:
		return
	_options_instance = options_scene.instantiate()
	_options_instance.back_requested.connect(_on_options_back)
	add_child(_options_instance)
	# Hide main buttons while options are open
	$CenterContainer.visible = false


func _on_options_back() -> void:
	if _options_instance:
		_options_instance.queue_free()
		_options_instance = null
	$CenterContainer.visible = true


func _on_quit_pressed() -> void:
	get_tree().quit()
