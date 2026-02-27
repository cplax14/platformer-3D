extends Control

## Level select screen — shows levels organized by world with star counts.
## Levels unlock sequentially within a world.
## World 2 unlocks when all 9 World 1 stars are collected.

const WORLDS: Array[Dictionary] = [
	{
		"name": "World 1 — Green Hills",
		"levels": [
			{"path": "res://src/levels/world_1/level_1_1.tscn", "name": "1-1: Grassy Start"},
			{"path": "res://src/levels/world_1/level_1_2.tscn", "name": "1-2: Rising Challenge"},
			{"path": "res://src/levels/world_1/level_1_3.tscn", "name": "1-3: The Gauntlet"},
			{"path": "res://src/levels/world_1/level_1_boss.tscn", "name": "Boss: King Slime"},
		],
	},
	{
		"name": "World 2 — Crystal Caves",
		"levels": [
			{"path": "res://src/levels/world_2/level_2_1.tscn", "name": "2-1: Crystal Descent"},
			{"path": "res://src/levels/world_2/level_2_2.tscn", "name": "2-2: The Deep"},
			{"path": "res://src/levels/world_2/level_2_3.tscn", "name": "2-3: Crystal Labyrinth"},
			{"path": "res://src/levels/world_2/level_2_boss.tscn", "name": "Boss: Crystal Golem"},
		],
	},
]

const W1_STAR_REQUIREMENT: int = 9  # Stars needed to unlock W2

var _current_world_index: int = 0

@onready var level_list: VBoxContainer = $MarginContainer/VBoxContainer/LevelList
@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_build_world_tabs()
	_build_level_buttons()


func _build_world_tabs() -> void:
	# Add world tab buttons above the level list
	var tab_container := HBoxContainer.new()
	tab_container.name = "WorldTabs"
	tab_container.add_theme_constant_override("separation", 8)

	for i in range(WORLDS.size()):
		var tab := Button.new()
		tab.text = "World %d" % (i + 1)
		tab.custom_minimum_size = Vector2(140, 40)
		tab.add_theme_font_size_override("font_size", 20)

		var world_unlocked := _is_world_unlocked(i)
		tab.disabled = not world_unlocked

		if world_unlocked:
			var world_idx := i
			tab.pressed.connect(func():
				_current_world_index = world_idx
				_build_level_buttons()
			)

		tab_container.add_child(tab)

	# Insert tabs before the level list
	var vbox := level_list.get_parent()
	vbox.add_child(tab_container)
	vbox.move_child(tab_container, level_list.get_index())


func _build_level_buttons() -> void:
	# Clear existing
	for child in level_list.get_children():
		child.queue_free()

	var world_data: Dictionary = WORLDS[_current_world_index]
	var levels: Array = world_data["levels"]
	var world_num := _current_world_index + 1

	# World title
	var title := Label.new()
	title.text = world_data["name"]
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_list.add_child(title)

	for i in range(levels.size()):
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)

		var button := Button.new()
		button.text = levels[i]["name"]
		button.custom_minimum_size = Vector2(300, 50)
		button.add_theme_font_size_override("font_size", 22)

		var unlocked := _is_level_unlocked(world_num, i)
		button.disabled = not unlocked

		if unlocked:
			var level_idx := i
			var w := world_num
			button.pressed.connect(func(): _on_level_pressed(w, level_idx))

		hbox.add_child(button)

		# Star display
		var star_label := Label.new()
		star_label.add_theme_font_size_override("font_size", 22)
		var level_id := "%d_%d" % [world_num, i + 1]
		var stars := GameManager.get_star_count(level_id)
		var star_text := ""
		for s in range(3):
			star_text += "★" if s < stars else "☆"
		star_label.text = star_text
		star_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0) if stars > 0 else Color(0.5, 0.5, 0.5))
		hbox.add_child(star_label)

		# Best time display
		var time_label := Label.new()
		time_label.add_theme_font_size_override("font_size", 18)
		var best_time := GameManager.get_best_time(level_id)
		if best_time >= 0.0:
			var minutes := int(best_time) / 60
			var secs := int(best_time) % 60
			var centiseconds := int(fmod(best_time, 1.0) * 100)
			time_label.text = "Best: %d:%02d.%02d" % [minutes, secs, centiseconds]
			time_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		else:
			time_label.text = ""
		hbox.add_child(time_label)

		level_list.add_child(hbox)

	# Show unlock hint for locked worlds
	if not _is_world_unlocked(_current_world_index):
		var hint := Label.new()
		hint.text = "Collect all World 1 stars to unlock!"
		hint.add_theme_font_size_override("font_size", 18)
		hint.add_theme_color_override("font_color", Color(0.7, 0.5, 0.2))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_list.add_child(hint)


func _is_world_unlocked(world_index: int) -> bool:
	if world_index == 0:
		return true
	# World 2 requires 9 stars across all W1 levels (1_1 through 1_4, including boss star)
	var w1_stars := 0
	for i in range(1, 5):
		w1_stars += GameManager.get_star_count("1_%d" % i)
	return w1_stars >= W1_STAR_REQUIREMENT


func _is_level_unlocked(world: int, level_index: int) -> bool:
	if not _is_world_unlocked(world - 1):
		return false
	if level_index == 0:
		return true  # First level of world always unlocked (if world is unlocked)

	# Previous level must have at least 1 star (completed)
	var prev_level_id := "%d_%d" % [world, level_index]
	return GameManager.get_star_count(prev_level_id) > 0


func _on_level_pressed(world: int, index: int) -> void:
	var level := index + 1
	GameManager.change_level(world, level)


func _on_back_pressed() -> void:
	SceneTransition.transition_to_scene("res://src/ui/main_menu.tscn")
