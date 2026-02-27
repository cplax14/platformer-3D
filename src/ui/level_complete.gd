extends CanvasLayer

## Level complete screen — shows stars earned, coins collected.
## Buttons: Next Level, Replay, Level Select.
## Also shows ability unlock notifications after boss defeats.

@onready var title_label: Label = $CenterContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var stars_label: Label = $CenterContainer/PanelContainer/VBoxContainer/StarsLabel
@onready var coins_label: Label = $CenterContainer/PanelContainer/VBoxContainer/CoinsLabel
@onready var next_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ButtonRow/NextButton
@onready var replay_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ButtonRow/ReplayButton
@onready var select_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ButtonRow/SelectButton

var _next_world: int = 1
var _next_level: int = 2

const ABILITY_DISPLAY_NAMES: Dictionary = {
	"wall_run": "Wall Run",
	"wall_slide": "Wall Slide",
	"dash": "Air Dash",
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	next_button.pressed.connect(_on_next_pressed)
	replay_button.pressed.connect(_on_replay_pressed)
	select_button.pressed.connect(_on_select_pressed)
	GameManager.ability_unlocked.connect(_on_ability_unlocked)


func show_results(world: int, level: int, next_w: int, next_l: int) -> void:
	_next_world = next_w
	_next_level = next_l

	get_tree().paused = true
	visible = true

	# Hide "Next" button if there's no next level (final boss)
	var next_path := GameManager._get_level_path(next_w, next_l)
	if not ResourceLoader.exists(next_path):
		next_button.visible = false

	# Title
	if level == 4:
		title_label.text = "Boss Defeated!"
	else:
		title_label.text = "Level %d-%d Complete!" % [world, level]

	# Stars
	var level_id := "%d_%d" % [world, level]
	var star_count := GameManager.get_star_count(level_id)
	var star_text := ""
	for i in range(3):
		star_text += " ★ " if i < star_count else " ☆ "
	stars_label.text = star_text

	# Coins
	coins_label.text = "Coins: %d" % GameManager.coins

	# Save progress
	SaveManager.save_game()

	# Animate stars appearing
	_animate_stars()


func _animate_stars() -> void:
	stars_label.scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_interval(0.3)
	tween.tween_property(stars_label, "scale", Vector2.ONE, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)


func _on_ability_unlocked(abilities: Array) -> void:
	_show_unlock_notification(abilities)


func _show_unlock_notification(abilities: Array) -> void:
	var vbox: VBoxContainer = $CenterContainer/PanelContainer/VBoxContainer

	var unlock_label := Label.new()
	unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unlock_label.add_theme_font_size_override("font_size", 26)
	unlock_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 1.0))

	var names: Array = []
	for ability_name in abilities:
		names.append(ABILITY_DISPLAY_NAMES.get(ability_name, ability_name))
	unlock_label.text = "NEW ABILITY: " + " & ".join(names) + "!"

	# Insert before the button row
	var button_row_idx := vbox.get_child_count() - 1  # ButtonRow is last
	vbox.add_child(unlock_label)
	vbox.move_child(unlock_label, button_row_idx)

	# Animate: bounce in
	unlock_label.scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_interval(0.8)
	tween.tween_property(unlock_label, "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)


func _on_next_pressed() -> void:
	get_tree().paused = false
	visible = false
	GameManager.change_level(_next_world, _next_level)


func _on_replay_pressed() -> void:
	get_tree().paused = false
	visible = false
	GameManager.change_level(GameManager.current_world, GameManager.current_level)


func _on_select_pressed() -> void:
	visible = false
	get_tree().paused = false
	SceneTransition.transition_to_scene("res://src/ui/level_select.tscn")
