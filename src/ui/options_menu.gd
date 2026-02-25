extends Control

## Options menu — volume sliders for Master, Music, and SFX.
## Can be opened from main menu or pause menu.

signal back_requested

@onready var master_slider: HSlider = $CenterContainer/PanelContainer/VBoxContainer/MasterRow/MasterSlider
@onready var music_slider: HSlider = $CenterContainer/PanelContainer/VBoxContainer/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $CenterContainer/PanelContainer/VBoxContainer/SFXRow/SFXSlider
@onready var back_button: Button = $CenterContainer/PanelContainer/VBoxContainer/BackButton


func _ready() -> void:
	# Load current volumes
	master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")))
	sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")))

	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	back_button.pressed.connect(_on_back_pressed)


func _on_master_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(value))


func _on_music_changed(value: float) -> void:
	var idx := AudioServer.get_bus_index("Music")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(value))


func _on_sfx_changed(value: float) -> void:
	var idx := AudioServer.get_bus_index("SFX")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(value))


func _on_back_pressed() -> void:
	SaveManager.save_game()
	back_requested.emit()
