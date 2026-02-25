extends CanvasLayer

## HUD — displays health hearts, coin count, and star indicators.

@onready var hearts_container: HBoxContainer = $MarginContainer/TopBar/Hearts
@onready var coin_label: Label = $MarginContainer/TopBar/CoinDisplay/CoinCount
@onready var star_1: TextureRect = $MarginContainer/TopBar/Stars/Star1
@onready var star_2: TextureRect = $MarginContainer/TopBar/Stars/Star2
@onready var star_3: TextureRect = $MarginContainer/TopBar/Stars/Star3

const HEART_FULL_COLOR := Color(1.0, 0.2, 0.2, 1.0)
const HEART_EMPTY_COLOR := Color(0.3, 0.3, 0.3, 0.5)
const STAR_COLLECTED_COLOR := Color(1.0, 0.85, 0.0, 1.0)
const STAR_EMPTY_COLOR := Color(0.4, 0.4, 0.4, 0.5)


func _ready() -> void:
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.coins_changed.connect(_on_coins_changed)
	GameManager.star_collected.connect(_on_star_collected)

	# Initialize display
	_on_health_changed(GameManager.health)
	_on_coins_changed(GameManager.coins)
	_refresh_stars()


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
