extends Control

## Level select screen — shows World 1 levels with star counts.
## Levels unlock sequentially (must complete previous to access next).

const LEVEL_PATHS: Array[String] = [
	"res://src/levels/world_1/level_1_1.tscn",
	"res://src/levels/world_1/level_1_2.tscn",
	"res://src/levels/world_1/level_1_3.tscn",
	"res://src/levels/world_1/level_1_boss.tscn",
]

const LEVEL_NAMES: Array[String] = [
	"1-1: Grassy Start",
	"1-2: Rising Challenge",
	"1-3: The Gauntlet",
	"Boss: King Slime",
]

@onready var level_list: VBoxContainer = $MarginContainer/VBoxContainer/LevelList
@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_build_level_buttons()


func _build_level_buttons() -> void:
	# Clear existing
	for child in level_list.get_children():
		child.queue_free()

	for i in range(LEVEL_PATHS.size()):
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)

		var button := Button.new()
		button.text = LEVEL_NAMES[i]
		button.custom_minimum_size = Vector2(300, 50)
		button.add_theme_font_size_override("font_size", 22)

		# Check if level is unlocked
		var unlocked := _is_level_unlocked(i)
		button.disabled = not unlocked

		if unlocked:
			var level_idx := i
			button.pressed.connect(func(): _on_level_pressed(level_idx))

		hbox.add_child(button)

		# Star display
		var star_label := Label.new()
		star_label.add_theme_font_size_override("font_size", 22)
		var level_id := "1_%d" % (i + 1)
		var stars := GameManager.get_star_count(level_id)
		var star_text := ""
		for s in range(3):
			star_text += "★" if s < stars else "☆"
		star_label.text = star_text
		star_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0) if stars > 0 else Color(0.5, 0.5, 0.5))
		hbox.add_child(star_label)

		level_list.add_child(hbox)


func _is_level_unlocked(level_index: int) -> bool:
	if level_index == 0:
		return true  # First level always unlocked

	# Previous level must have at least 1 star (completed)
	var prev_level_id := "1_%d" % level_index
	return GameManager.get_star_count(prev_level_id) > 0


func _on_level_pressed(index: int) -> void:
	var world := 1
	var level := index + 1
	GameManager.change_level(world, level)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")
