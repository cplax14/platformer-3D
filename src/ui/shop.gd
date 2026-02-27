extends Control

## Shop — spend coins on cosmetic player colors.

signal back_requested

const COLOR_CATALOG: Array = [
	{"key": "blue", "label": "Blue", "color": Color(0.2, 0.6, 1.0), "cost": 0},
	{"key": "red", "label": "Red", "color": Color(1.0, 0.25, 0.2), "cost": 50},
	{"key": "green", "label": "Green", "color": Color(0.2, 0.85, 0.3), "cost": 50},
	{"key": "pink", "label": "Pink", "color": Color(1.0, 0.4, 0.7), "cost": 75},
	{"key": "gold", "label": "Gold", "color": Color(1.0, 0.85, 0.0), "cost": 100},
	{"key": "purple", "label": "Purple", "color": Color(0.6, 0.2, 0.9), "cost": 100},
]

var _coin_label: Label
var _grid: GridContainer
var _color_buttons: Dictionary = {}  # key -> Button


func _ready() -> void:
	_build_ui()
	_refresh_buttons()


func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.12, 0.25, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(550, 0)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Color Shop"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Coin bank display
	var coin_row := HBoxContainer.new()
	coin_row.alignment = BoxContainer.ALIGNMENT_CENTER
	coin_row.add_theme_constant_override("separation", 8)
	vbox.add_child(coin_row)

	var coin_icon := Label.new()
	coin_icon.text = "●"
	coin_icon.add_theme_font_size_override("font_size", 24)
	coin_icon.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0, 1.0))
	coin_row.add_child(coin_icon)

	_coin_label = Label.new()
	_coin_label.add_theme_font_size_override("font_size", 24)
	_coin_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_coin_label.text = str(GameManager.coin_bank)
	coin_row.add_child(_coin_label)

	# Grid of color buttons
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	vbox.add_child(_grid)

	for item in COLOR_CATALOG:
		var btn_vbox := VBoxContainer.new()
		btn_vbox.add_theme_constant_override("separation", 4)

		# Color swatch
		var swatch := ColorRect.new()
		swatch.color = item["color"]
		swatch.custom_minimum_size = Vector2(60, 60)
		swatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn_vbox.add_child(swatch)

		# Label
		var label := Label.new()
		label.text = item["label"]
		label.add_theme_font_size_override("font_size", 16)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn_vbox.add_child(label)

		# Action button
		var button := Button.new()
		button.custom_minimum_size = Vector2(140, 40)
		button.add_theme_font_size_override("font_size", 18)
		btn_vbox.add_child(button)

		var color_key: String = item["key"]
		var color_cost: int = item["cost"]
		button.pressed.connect(func(): _on_color_button_pressed(color_key, color_cost))

		_color_buttons[color_key] = button
		_grid.add_child(btn_vbox)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Back button
	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(250, 50)
	back_btn.add_theme_font_size_override("font_size", 24)
	back_btn.pressed.connect(_on_back_pressed)
	vbox.add_child(back_btn)


func _refresh_buttons() -> void:
	_coin_label.text = str(GameManager.coin_bank)

	for item in COLOR_CATALOG:
		var key: String = item["key"]
		var cost: int = item["cost"]
		var button: Button = _color_buttons[key]

		if key == GameManager.selected_color:
			button.text = "Selected"
			button.disabled = true
		elif key in GameManager.owned_colors:
			button.text = "Select"
			button.disabled = false
		else:
			button.text = "Buy (%d)" % cost
			button.disabled = GameManager.coin_bank < cost


func _on_color_button_pressed(color_key: String, cost: int) -> void:
	if color_key in GameManager.owned_colors:
		# Already owned — select it
		GameManager.select_color(color_key)
	else:
		# Try to buy
		if GameManager.buy_color(color_key, cost):
			GameManager.select_color(color_key)

	_refresh_buttons()


func _on_back_pressed() -> void:
	SaveManager.save_game()
	back_requested.emit()
