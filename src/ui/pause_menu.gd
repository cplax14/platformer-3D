extends CanvasLayer

## Pause menu — resume, options, restart level, or quit to main menu.

@onready var panel: PanelContainer = $CenterContainer/PanelContainer
@onready var buttons_container: VBoxContainer = $CenterContainer/PanelContainer/VBoxContainer

var _options_scene := preload("res://src/ui/options_menu.tscn")
var _options_instance: Control = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# If options are open, close them first
		if _options_instance:
			_on_options_back()
			get_viewport().set_input_as_handled()
			return
		if visible:
			resume()
		else:
			pause()
		get_viewport().set_input_as_handled()


func pause() -> void:
	visible = true
	get_tree().paused = true


func resume() -> void:
	visible = false
	get_tree().paused = false


func _on_resume_pressed() -> void:
	resume()


func _on_options_pressed() -> void:
	if _options_instance:
		return
	_options_instance = _options_scene.instantiate()
	_options_instance.back_requested.connect(_on_options_back)
	add_child(_options_instance)
	panel.visible = false


func _on_options_back() -> void:
	if _options_instance:
		_options_instance.queue_free()
		_options_instance = null
	panel.visible = true


func _on_restart_pressed() -> void:
	resume()
	GameManager.change_level(GameManager.current_world, GameManager.current_level)


func _on_quit_pressed() -> void:
	resume()
	GameManager.reset_game()
	SceneTransition.transition_to_scene("res://src/ui/main_menu.tscn")
