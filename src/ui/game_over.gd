extends CanvasLayer

## Game over screen — shown when player runs out of lives.
## Options: Retry (restart current level with fresh lives) or Quit to menu.

@onready var retry_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ButtonRow/RetryButton
@onready var quit_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ButtonRow/QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	visible = false
	retry_button.pressed.connect(_on_retry_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func show_game_over() -> void:
	get_tree().paused = true
	visible = true
	_animate_in()


func _animate_in() -> void:
	var panel: PanelContainer = $CenterContainer/PanelContainer
	panel.scale = Vector2(0.5, 0.5)
	panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)


func _on_retry_pressed() -> void:
	get_tree().paused = false
	visible = false
	GameManager.lives = 3
	GameManager.lives_changed.emit(GameManager.lives)
	GameManager.change_level(GameManager.current_world, GameManager.current_level)


func _on_quit_pressed() -> void:
	get_tree().paused = false
	visible = false
	GameManager.reset_game()
	SceneTransition.transition_to_scene("res://src/ui/main_menu.tscn")
