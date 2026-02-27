extends Node3D

## Base level script — shared logic for all levels.
## Handles level completion, fall-off-edge respawn, star tracking,
## time trial timer, and ghost replay recording/playback.

@export var world_id: int = 1
@export var level_id: int = 1
@export var fall_depth: float = -15.0  # Y position that triggers respawn

var _player: CharacterBody3D = null
var _spawn_position: Vector3 = Vector3.ZERO

# Time trial
var _trial_time: float = 0.0

# Ghost recording
var _ghost_positions: PackedVector3Array = PackedVector3Array()
var _ghost_rotations: PackedFloat32Array = PackedFloat32Array()
var _ghost_frame_counter: int = 0

# Ghost playback
var _ghost_mesh: MeshInstance3D = null
var _ghost_playback_index: int = 0
var _ghost_playback_positions: PackedVector3Array = PackedVector3Array()
var _ghost_playback_rotations: PackedFloat32Array = PackedFloat32Array()


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

	# Start trial timer
	_trial_time = 0.0
	GameManager.trial_active = true
	GameManager.trial_time = 0.0

	# Setup ghost playback from previous run
	_setup_ghost_playback()


func _physics_process(delta: float) -> void:
	if not _player:
		return

	# Respawn if fallen off the level (no damage — just reposition)
	if _player.global_position.y < fall_depth:
		_respawn_player()

	# Update trial timer (fall respawn does NOT reset — it's a penalty)
	if GameManager.trial_active:
		_trial_time += delta
		GameManager.trial_time = _trial_time

	# Record ghost data every 5 physics frames
	_ghost_frame_counter += 1
	if _ghost_frame_counter % 5 == 0:
		_ghost_positions.append(_player.global_position)
		_ghost_rotations.append(_player.rotation.y)

	# Playback ghost
	_update_ghost_playback()


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
	# Stop trial timer
	GameManager.trial_active = false

	# Record best time
	var lid := "%d_%d" % [world_id, level_id]
	GameManager.record_best_time(lid, _trial_time)

	# Store ghost data for this level (runtime only, not persisted)
	GameManager.ghost_data[lid] = {
		"positions": _ghost_positions.duplicate(),
		"rotations": _ghost_rotations.duplicate(),
	}

	# Collect the completion star (star 0) automatically
	GameManager.collect_star(0)

	# Refresh abilities (may emit ability_unlocked signal for boss levels)
	GameManager.refresh_abilities()

	SaveManager.save_game()


# --- Ghost Replay ---

func _setup_ghost_playback() -> void:
	var lid := "%d_%d" % [world_id, level_id]
	if not GameManager.ghost_data.has(lid):
		return

	var data: Dictionary = GameManager.ghost_data[lid]
	_ghost_playback_positions = data.get("positions", PackedVector3Array())
	_ghost_playback_rotations = data.get("rotations", PackedFloat32Array())

	if _ghost_playback_positions.size() == 0:
		return

	# Create transparent ghost mesh
	_ghost_mesh = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.25
	capsule.height = 1.2
	_ghost_mesh.mesh = capsule

	var ghost_mat := StandardMaterial3D.new()
	ghost_mat.albedo_color = Color(0.5, 0.8, 1.0, 0.3)
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mesh.material_override = ghost_mat

	_ghost_mesh.position = _ghost_playback_positions[0]
	_ghost_mesh.position.y += 0.6  # Offset to center of player
	_ghost_playback_index = 0

	add_child(_ghost_mesh)


func _update_ghost_playback() -> void:
	if not _ghost_mesh or not _ghost_mesh.visible:
		return
	if _ghost_playback_positions.size() == 0:
		return

	# Advance ghost every 5 physics frames (matching recording rate)
	if _ghost_frame_counter % 5 != 0:
		return

	_ghost_playback_index += 1
	if _ghost_playback_index >= _ghost_playback_positions.size():
		# Ghost finished — hide it
		_ghost_mesh.visible = false
		return

	var pos := _ghost_playback_positions[_ghost_playback_index]
	_ghost_mesh.global_position = pos + Vector3(0, 0.6, 0)

	if _ghost_playback_index < _ghost_playback_rotations.size():
		_ghost_mesh.rotation.y = _ghost_playback_rotations[_ghost_playback_index]
