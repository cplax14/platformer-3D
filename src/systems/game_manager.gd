extends Node

## GameManager autoload — central game state.
## Tracks player health, coins, stars, lives, and handles level transitions.

signal health_changed(new_health: int)
signal coins_changed(new_coins: int)
signal lives_changed(new_lives: int)
signal star_collected(level_id: String, star_index: int)
signal player_died

# Player state
var max_health: int = 5
var health: int = 5
var coins: int = 0
var lives: int = 3
var is_invincible: bool = false

# Level state
var current_world: int = 1
var current_level: int = 1
var collected_stars: Dictionary = {}  # { "1_1": [true, false, true] }

# Coins needed for extra life
const COINS_PER_LIFE: int = 30

# Invincibility after damage
const INVINCIBILITY_DURATION: float = 2.0
var _invincibility_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Run even when paused


func _process(delta: float) -> void:
	if _invincibility_timer > 0.0:
		_invincibility_timer -= delta
		if _invincibility_timer <= 0.0:
			is_invincible = false


func reset_level_state() -> void:
	health = max_health
	coins = 0
	is_invincible = false
	_invincibility_timer = 0.0
	health_changed.emit(health)
	coins_changed.emit(coins)


func reset_game() -> void:
	health = max_health
	coins = 0
	lives = 3
	current_world = 1
	current_level = 1
	is_invincible = false
	_invincibility_timer = 0.0
	collected_stars.clear()
	health_changed.emit(health)
	coins_changed.emit(coins)
	lives_changed.emit(lives)


func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)

	# Extra life every COINS_PER_LIFE coins
	while coins >= COINS_PER_LIFE:
		coins -= COINS_PER_LIFE
		add_life()
		coins_changed.emit(coins)


func add_life() -> void:
	lives += 1
	lives_changed.emit(lives)


func take_damage(amount: int = 1) -> void:
	if is_invincible:
		return

	health = maxi(health - amount, 0)
	health_changed.emit(health)

	if health <= 0:
		_on_player_death()
	else:
		is_invincible = true
		_invincibility_timer = INVINCIBILITY_DURATION


func heal(amount: int) -> void:
	health = mini(health + amount, max_health)
	health_changed.emit(health)


func collect_star(star_index: int) -> void:
	var level_id := _get_level_id()
	if not collected_stars.has(level_id):
		collected_stars[level_id] = [false, false, false]
	collected_stars[level_id][star_index] = true
	star_collected.emit(level_id, star_index)


func get_star_count(level_id: String) -> int:
	if not collected_stars.has(level_id):
		return 0
	var count := 0
	for star in collected_stars[level_id]:
		if star:
			count += 1
	return count


func get_total_stars() -> int:
	var total := 0
	for level_id in collected_stars:
		total += get_star_count(level_id)
	return total


var _game_over_scene := preload("res://src/ui/game_over.tscn")


func _on_player_death() -> void:
	lives -= 1
	lives_changed.emit(lives)
	player_died.emit()

	if lives >= 0:
		# Respawn at checkpoint — reload current level
		reset_level_state()
		var level_path := _get_level_path(current_world, current_level)
		get_tree().call_deferred("change_scene_to_file", level_path)
	else:
		# Game over — show game over screen
		_show_game_over()


func _show_game_over() -> void:
	var game_over_ui := _game_over_scene.instantiate()
	get_tree().root.add_child(game_over_ui)
	game_over_ui.show_game_over()


func change_level(world: int, level: int) -> void:
	current_world = world
	current_level = level
	reset_level_state()
	var level_path := _get_level_path(world, level)
	get_tree().call_deferred("change_scene_to_file", level_path)


func _get_level_path(world: int, level: int) -> String:
	# Boss levels use a different naming convention
	if level == 4:
		return "res://src/levels/world_%d/level_%d_boss.tscn" % [world, world]
	return "res://src/levels/world_%d/level_%d_%d.tscn" % [world, world, level]


func _get_level_id() -> String:
	return "%d_%d" % [current_world, current_level]
