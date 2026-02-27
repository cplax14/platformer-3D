extends Control

## Options menu — volume sliders for Master, Music, and SFX.
## Also includes difficulty assist toggles.
## Can be opened from main menu or pause menu.

signal back_requested

@onready var master_slider: HSlider = $CenterContainer/PanelContainer/VBoxContainer/MasterRow/MasterSlider
@onready var music_slider: HSlider = $CenterContainer/PanelContainer/VBoxContainer/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $CenterContainer/PanelContainer/VBoxContainer/SFXRow/SFXSlider
@onready var back_button: Button = $CenterContainer/PanelContainer/VBoxContainer/BackButton

# Assist check buttons — created dynamically
var _assist_buttons: Dictionary = {}

const ASSIST_LABELS: Dictionary = {
	"assist_coyote": "Long Coyote Time",
	"assist_slow_fall": "Slow Fall",
	"assist_inf_jumps": "Infinite Double Jumps",
	"assist_wall_angles": "Easy Wall Angles",
}


func _ready() -> void:
	# Load current volumes
	master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")))
	sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")))

	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	back_button.pressed.connect(_on_back_pressed)

	_build_assist_toggles()


func _build_assist_toggles() -> void:
	var vbox: VBoxContainer = $CenterContainer/PanelContainer/VBoxContainer
	var spacer2 := $CenterContainer/PanelContainer/VBoxContainer/Spacer2
	var insert_idx := spacer2.get_index()

	# Section header
	var header := Label.new()
	header.text = "Assists"
	header.add_theme_font_size_override("font_size", 28)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0, 1.0))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)
	vbox.move_child(header, insert_idx)
	insert_idx += 1

	# Small spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 5)
	vbox.add_child(spacer)
	vbox.move_child(spacer, insert_idx)
	insert_idx += 1

	# Create a CheckButton for each assist
	for key in ASSIST_LABELS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)

		var check := CheckButton.new()
		check.text = ASSIST_LABELS[key]
		check.add_theme_font_size_override("font_size", 20)
		check.button_pressed = GameManager.get_assist(key)
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var assist_key: String = key
		check.toggled.connect(func(pressed: bool):
			GameManager.set_assist(assist_key, pressed)
		)

		row.add_child(check)
		vbox.add_child(row)
		vbox.move_child(row, insert_idx)
		insert_idx += 1
		_assist_buttons[key] = check


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
