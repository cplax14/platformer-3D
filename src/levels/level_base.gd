extends Node3D

## Base level script — shared logic for all levels.
## Handles level completion, fall-off-edge respawn, and star tracking.

@export var world_id: int = 1
@export var level_id: int = 1
@export var fall_depth: float = -15.0  # Y position that triggers respawn

var _player: CharacterBody3D = null
var _spawn_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	GameManager.current_world = world_id
	GameManager.current_level = level_id

	# Find the player and store spawn position
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]
		_spawn_position = _player.global_position

	# Auto-connect boss death to LevelEnd activation for boss levels
	_connect_boss_level_end()

	# Play world/boss music
	_start_music()


func _physics_process(_delta: float) -> void:
	if not _player:
		return

	# Respawn if fallen off the level (no damage — just reposition)
	if _player.global_position.y < fall_depth:
		_respawn_player()


func _respawn_player() -> void:
	if not _player:
		return
	_player.global_position = _spawn_position
	_player.velocity = Vector3.ZERO


func _connect_boss_level_end() -> void:
	# Find any boss node with boss_died signal and connect to LevelEnd
	for child in get_children():
		if child.has_signal("boss_died"):
			var level_end := _find_level_end()
			if level_end:
				level_end.visible = false
				# Disable collision so player can't trigger it early
				level_end.set_deferred("monitoring", false)
				child.boss_died.connect(func():
					level_end.visible = true
					level_end.set_deferred("monitoring", true)
					Particles.spawn_crystal_sparkle(level_end.global_position + Vector3(0, 1.5, 0))
				)
			break


func _find_level_end() -> Area3D:
	for child in get_children():
		if child.name == "LevelEnd" and child is Area3D:
			return child
	return null


func _start_music() -> void:
	# Check for boss node — play boss music if present
	var has_boss := false
	for child in get_children():
		if child.has_signal("boss_died"):
			has_boss = true
			break

	if has_boss:
		AudioManager.play_music(MusicLibrary.boss)
	elif world_id == 1:
		AudioManager.play_music(MusicLibrary.world_1)
	elif world_id == 2:
		AudioManager.play_music(MusicLibrary.world_2)


func complete_level() -> void:
	# Collect the completion star (star 0) automatically
	GameManager.collect_star(0)
	SaveManager.save_game()
