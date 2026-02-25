extends Node

## SaveManager autoload — persists game progress to user:// as JSON.

const SAVE_PATH: String = "user://save_data.json"

# Default save structure
var _default_data: Dictionary = {
	"collected_stars": {},
	"unlocked_worlds": [1],
	"settings": {
		"master_volume": 1.0,
		"music_volume": 0.8,
		"sfx_volume": 1.0,
	},
}


func save_game() -> void:
	var data := {
		"collected_stars": GameManager.collected_stars.duplicate(true),
		"unlocked_worlds": _get_unlocked_worlds(),
		"settings": _get_settings(),
	}

	var json_string := JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var result := json.parse(json_string)
	if result != OK:
		push_warning("SaveManager: Failed to parse save file")
		return

	var data: Dictionary = json.data
	if not data is Dictionary:
		push_warning("SaveManager: Save data is not a dictionary")
		return

	# Restore stars
	if data.has("collected_stars"):
		GameManager.collected_stars = data["collected_stars"]

	# Restore settings
	if data.has("settings"):
		_apply_settings(data["settings"])


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func _get_unlocked_worlds() -> Array:
	# Unlock next world when all stars in current world collected
	var unlocked := [1]
	for world in range(1, 4):
		var all_stars := true
		for level in range(1, 4):
			var level_id := "%d_%d" % [world, level]
			if GameManager.get_star_count(level_id) < 3:
				all_stars = false
				break
		if all_stars and world + 1 <= 3:
			unlocked.append(world + 1)
	return unlocked


func _get_settings() -> Dictionary:
	return {
		"master_volume": db_to_linear(AudioServer.get_bus_volume_db(0)),
		"music_volume": db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))),
		"sfx_volume": db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))),
	}


func _apply_settings(settings: Dictionary) -> void:
	if settings.has("master_volume"):
		AudioServer.set_bus_volume_db(0, linear_to_db(settings["master_volume"]))
	if settings.has("music_volume"):
		var music_idx := AudioServer.get_bus_index("Music")
		if music_idx >= 0:
			AudioServer.set_bus_volume_db(music_idx, linear_to_db(settings["music_volume"]))
	if settings.has("sfx_volume"):
		var sfx_idx := AudioServer.get_bus_index("SFX")
		if sfx_idx >= 0:
			AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(settings["sfx_volume"]))
