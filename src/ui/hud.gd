extends CanvasLayer

## HUD — displays health hearts, coin count, star indicators, and boss HP bar.

@onready var hearts_container: HBoxContainer = $MarginContainer/TopBar/Hearts
@onready var coin_label: Label = $MarginContainer/TopBar/CoinDisplay/CoinCount
@onready var star_1: TextureRect = $MarginContainer/TopBar/Stars/Star1
@onready var star_2: TextureRect = $MarginContainer/TopBar/Stars/Star2
@onready var star_3: TextureRect = $MarginContainer/TopBar/Stars/Star3

const HEART_FULL_COLOR := Color(1.0, 0.2, 0.2, 1.0)
const HEART_EMPTY_COLOR := Color(0.3, 0.3, 0.3, 0.5)
const STAR_COLLECTED_COLOR := Color(1.0, 0.85, 0.0, 1.0)
const STAR_EMPTY_COLOR := Color(0.4, 0.4, 0.4, 0.5)

const BOSS_BAR_COLOR := Color(0.9, 0.15, 0.15, 1.0)
const BOSS_BAR_BG_COLOR := Color(0.2, 0.2, 0.2, 0.8)
const BOSS_BAR_FLASH_COLOR := Color(1.0, 1.0, 0.3, 1.0)

var _boss_bar_container: VBoxContainer
var _boss_name_label: Label
var _boss_bar_bg: ColorRect
var _boss_bar_fill: ColorRect
var _boss_max_hp: int = 1


func _ready() -> void:
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.coins_changed.connect(_on_coins_changed)
	GameManager.star_collected.connect(_on_star_collected)

	# Initialize display
	_on_health_changed(GameManager.health)
	_on_coins_changed(GameManager.coins)
	_refresh_stars()

	# Search for boss and connect HP bar
	_setup_boss_bar()


func _on_health_changed(new_health: int) -> void:
	var heart_icons := hearts_container.get_children()
	for i in range(heart_icons.size()):
		var heart: Label = heart_icons[i]
		var was_full := heart.modulate == HEART_FULL_COLOR
		heart.modulate = HEART_FULL_COLOR if i < new_health else HEART_EMPTY_COLOR
		# Shake hearts that just lost health
		if was_full and i >= new_health:
			Juice.bounce(heart, 1.5, 0.3)


func _on_coins_changed(new_coins: int) -> void:
	coin_label.text = str(new_coins)
	Juice.bounce(coin_label, 1.3, 0.2)


func _on_star_collected(_level_id: String, _star_index: int) -> void:
	_refresh_stars()
	# Bounce all star labels
	var star_nodes := [star_1, star_2, star_3]
	for node in star_nodes:
		Juice.bounce(node, 1.4, 0.3)


func _refresh_stars() -> void:
	var level_id := "%d_%d" % [GameManager.current_world, GameManager.current_level]
	var stars_arr: Array = GameManager.collected_stars.get(level_id, [false, false, false])
	var star_nodes := [star_1, star_2, star_3]
	for i in range(3):
		if i < stars_arr.size() and stars_arr[i]:
			star_nodes[i].modulate = STAR_COLLECTED_COLOR
		else:
			star_nodes[i].modulate = STAR_EMPTY_COLOR


func _setup_boss_bar() -> void:
	# Wait a frame for the scene to fully load, then find boss
	await get_tree().process_frame
	var level_root := get_tree().current_scene
	if not level_root:
		return

	for child in level_root.get_children():
		if child.has_signal("health_changed") and child.has_signal("boss_died"):
			_create_boss_bar_ui(child)
			child.health_changed.connect(_on_boss_health_changed)
			child.boss_died.connect(_on_boss_died)
			break


func _create_boss_bar_ui(boss: Node) -> void:
	# Container at bottom center of screen
	_boss_bar_container = VBoxContainer.new()
	_boss_bar_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_boss_bar_container.offset_top = -80.0
	_boss_bar_container.offset_bottom = -30.0
	_boss_bar_container.offset_left = 100.0
	_boss_bar_container.offset_right = -100.0
	_boss_bar_container.alignment = BoxContainer.ALIGNMENT_CENTER

	# Boss name label
	_boss_name_label = Label.new()
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_label.add_theme_font_size_override("font_size", 20)
	_boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.8))
	# Determine boss name from the node name or scene context
	if boss.name.contains("Boss1") or boss.name.contains("boss_1"):
		_boss_name_label.text = "King Slime"
	else:
		_boss_name_label.text = "Crystal Golem"
	_boss_bar_container.add_child(_boss_name_label)

	# HP bar background
	_boss_bar_bg = ColorRect.new()
	_boss_bar_bg.color = BOSS_BAR_BG_COLOR
	_boss_bar_bg.custom_minimum_size = Vector2(0, 16)
	_boss_bar_container.add_child(_boss_bar_bg)

	# HP bar fill (child of bg so it overlays)
	_boss_bar_fill = ColorRect.new()
	_boss_bar_fill.color = BOSS_BAR_COLOR
	_boss_bar_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boss_bar_bg.add_child(_boss_bar_fill)

	# Add to the HUD's CanvasLayer
	add_child(_boss_bar_container)

	# Get max HP from initial emit
	if boss.has_method("_ready"):
		_boss_max_hp = boss.max_hp


func _on_boss_health_changed(current_hp: int, max_hp: int) -> void:
	_boss_max_hp = max_hp
	if not _boss_bar_fill:
		return

	var ratio := float(current_hp) / float(max_hp)
	# Animate the bar shrinking
	var tween := create_tween()
	tween.tween_property(_boss_bar_fill, "anchor_right", ratio, 0.2).set_ease(Tween.EASE_OUT)

	# Flash white on hit
	_boss_bar_fill.color = BOSS_BAR_FLASH_COLOR
	var color_tween := create_tween()
	color_tween.tween_property(_boss_bar_fill, "color", BOSS_BAR_COLOR, 0.3)

	# Bounce the boss name
	if _boss_name_label:
		Juice.bounce(_boss_name_label, 1.3, 0.2)


func _on_boss_died() -> void:
	if _boss_bar_container:
		var tween := create_tween()
		tween.tween_property(_boss_bar_container, "modulate:a", 0.0, 0.5)
		tween.tween_callback(_boss_bar_container.queue_free)
