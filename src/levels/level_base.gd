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


func complete_level() -> void:
	# Collect the completion star (star 0) automatically
	GameManager.collect_star(0)
	SaveManager.save_game()
