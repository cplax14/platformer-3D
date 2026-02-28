extends Node

## GameManager autoload — central game state.
## Tracks player health, coins, stars, lives, and handles level transitions.
## Also manages ability unlocks, coin bank, color shop, assists, and time trials.

signal health_changed(new_health: int)
signal coins_changed(new_coins: int)
signal lives_changed(new_lives: int)
signal star_collected(level_id: String, star_index: int)
signal player_died
signal ability_unlocked(ability_names: Array)
signal new_best_time(level_id: String, time: float)

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

# --- Tier 5: Ability Unlock Progression ---
var unlocked_abilities: Dictionary = {"wall_run": false, "wall_slide": false, "dash": false, "grapple": false}

# --- Tier 5: Coin Bank & Color Shop ---
var coin_bank: int = 0
var owned_colors: Array = ["blue"]
var selected_color: String = "blue"

# --- Tier 5: Difficulty Assists ---
var assists: Dictionary = {
	"assist_coyote": false,
	"assist_slow_fall": false,
	"assist_inf_jumps": false,
	"assist_wall_angles": false,
}

# --- Tier 5: Time Trial ---
var trial_active: bool = false
var trial_time: float = 0.0
var best_times: Dictionary = {}  # { "1_1": 42.5 }
var ghost_data: Dictionary = {}  # { "1_1": { "positions": [...], "rotations": [...] } } — runtime only


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
	trial_active = true
	trial_time = 0.0
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
	coin_bank = 0
	owned_colors = ["blue"]
	selected_color = "blue"
	unlocked_abilities = {"wall_run": false, "wall_slide": false, "dash": false, "grapple": false}
	assists = {
		"assist_coyote": false,
		"assist_slow_fall": false,
		"assist_inf_jumps": false,
		"assist_wall_angles": false,
	}
	best_times.clear()
	ghost_data.clear()
	trial_active = false
	trial_time = 0.0
	health_changed.emit(health)
	coins_changed.emit(coins)
	lives_changed.emit(lives)


func add_coins(amount: int) -> void:
	coins += amount
	coin_bank += amount
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


# --- Ability Unlock ---

func is_ability_unlocked(ability_name: String) -> bool:
	return unlocked_abilities.get(ability_name, false)


func refresh_abilities() -> void:
	var old_abilities := unlocked_abilities.duplicate()

	# Beat World 1 boss (star on "1_4") -> wall_slide + wall_run + dash
	var w1_boss_beaten := _has_boss_star("1_4")
	unlocked_abilities["wall_run"] = w1_boss_beaten
	unlocked_abilities["wall_slide"] = w1_boss_beaten
	unlocked_abilities["dash"] = w1_boss_beaten

	# Beat World 2 boss (star on "2_4") -> grapple
	var w2_boss_beaten := _has_boss_star("2_4")
	unlocked_abilities["grapple"] = w2_boss_beaten

	# Check for newly unlocked abilities
	var newly_unlocked: Array = []
	for ability_name in unlocked_abilities:
		if unlocked_abilities[ability_name] and not old_abilities.get(ability_name, false):
			newly_unlocked.append(ability_name)

	if newly_unlocked.size() > 0:
		ability_unlocked.emit(newly_unlocked)


func _has_boss_star(level_id: String) -> bool:
	if not collected_stars.has(level_id):
		return false
	var stars: Array = collected_stars[level_id]
	return stars.size() > 0 and stars[0] == true


# --- Color Shop ---

func buy_color(color_name: String, cost: int) -> bool:
	if coin_bank < cost:
		return false
	if color_name in owned_colors:
		return false
	coin_bank -= cost
	owned_colors.append(color_name)
	return true


func select_color(color_name: String) -> void:
	if color_name in owned_colors:
		selected_color = color_name


# --- Assists ---

func get_assist(key: String) -> bool:
	return assists.get(key, false)


func set_assist(key: String, value: bool) -> void:
	assists[key] = value


# --- Time Trial ---

func record_best_time(level_id: String, time: float) -> bool:
	if not best_times.has(level_id) or time < best_times[level_id]:
		best_times[level_id] = time
		new_best_time.emit(level_id, time)
		return true
	return false


func get_best_time(level_id: String) -> float:
	return best_times.get(level_id, -1.0)


# --- Death / Level Flow ---

var _game_over_scene := preload("res://src/ui/game_over.tscn")


func _on_player_death() -> void:
	lives -= 1
	lives_changed.emit(lives)
	player_died.emit()

	if lives > 0:
		# Respawn at checkpoint — reload current level
		reset_level_state()
		var level_path := _get_level_path(current_world, current_level)
		SceneTransition.transition_to_scene(level_path, SceneTransition.Type.FADE)
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
	SceneTransition.transition_to_scene(level_path)


func _get_level_path(world: int, level: int) -> String:
	# Boss levels use a different naming convention
	if level == 4:
		return "res://src/levels/world_%d/level_%d_boss.tscn" % [world, world]
	return "res://src/levels/world_%d/level_%d_%d.tscn" % [world, world, level]


func _get_level_id() -> String:
	return "%d_%d" % [current_world, current_level]
