extends Node

## AudioManager autoload — handles SFX pooling and music crossfade.

# SFX pool size (reuses players to avoid creating/destroying them)
const SFX_POOL_SIZE: int = 12
const MUSIC_FADE_DURATION: float = 1.0

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0

var _music_player_a: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer
var _active_music_player: AudioStreamPlayer
var _fade_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Create SFX pool
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_pool.append(player)

	# Create two music players for crossfading
	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.bus = "Music"
	add_child(_music_player_a)

	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.bus = "Music"
	add_child(_music_player_b)

	_active_music_player = _music_player_a


func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not stream:
		return

	var player := _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % SFX_POOL_SIZE

	# Stop if already playing (reuse oldest)
	if player.playing:
		player.stop()

	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


func play_sfx_random_pitch(stream: AudioStream, volume_db: float = 0.0, min_pitch: float = 0.9, max_pitch: float = 1.1) -> void:
	var pitch := randf_range(min_pitch, max_pitch)
	play_sfx(stream, volume_db, pitch)


func play_music(stream: AudioStream, fade: bool = true) -> void:
	if not stream:
		stop_music()
		return

	# Don't restart the same track
	if _active_music_player.stream == stream and _active_music_player.playing:
		return

	if fade:
		_crossfade_to(stream)
	else:
		_active_music_player.stop()
		_active_music_player.stream = stream
		_active_music_player.volume_db = 0.0
		_active_music_player.play()


func stop_music(fade: bool = true) -> void:
	if fade:
		_fade_out(_active_music_player)
	else:
		_active_music_player.stop()


func _crossfade_to(stream: AudioStream) -> void:
	if _fade_tween:
		_fade_tween.kill()

	# Swap active player
	var old_player := _active_music_player
	var new_player := _music_player_b if _active_music_player == _music_player_a else _music_player_a
	_active_music_player = new_player

	# Start new track quietly
	new_player.stream = stream
	new_player.volume_db = -40.0
	new_player.play()

	# Crossfade
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(old_player, "volume_db", -40.0, MUSIC_FADE_DURATION)
	_fade_tween.tween_property(new_player, "volume_db", 0.0, MUSIC_FADE_DURATION)
	_fade_tween.chain().tween_callback(old_player.stop)


func _fade_out(player: AudioStreamPlayer) -> void:
	if _fade_tween:
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.tween_property(player, "volume_db", -40.0, MUSIC_FADE_DURATION)
	_fade_tween.tween_callback(player.stop)
