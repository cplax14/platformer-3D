extends BaseEnemy

## Crystal Bat — flying enemy that hovers and swoops at the player.
## States: HOVERING → SWOOPING → RETURNING
## No gravity (flying). 1 HP.

enum BatState { HOVERING, SWOOPING, RETURNING }

@export var hover_height: float = 3.0
@export var patrol_speed: float = 1.5
@export var patrol_distance: float = 3.0
@export var detect_range: float = 8.0
@export var swoop_speed: float = 12.0
@export var return_speed: float = 4.0

var _state: BatState = BatState.HOVERING
var _start_position: Vector3
var _hover_position: Vector3
var _patrol_direction: float = 1.0
var _swoop_target: Vector3
var _time: float = 0.0
var _player: CharacterBody3D = null

@onready var player_damage_area: Area3D = $PlayerDamageArea


func _enemy_ready() -> void:
	gravity = 0.0  # Flying enemy
	_start_position = global_position
	_hover_position = _start_position + Vector3(0, hover_height, 0)
	global_position = _hover_position

	player_damage_area.body_entered.connect(_on_player_contact)

	if mesh and MaterialLibrary:
		mesh.material_override = MaterialLibrary.get_material("crystal_bat")

	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]


func _enemy_process(delta: float) -> void:
	_time += delta

	match _state:
		BatState.HOVERING:
			_process_hovering(delta)
		BatState.SWOOPING:
			_process_swooping(delta)
		BatState.RETURNING:
			_process_returning(delta)

	# Wing flap animation
	var flap := sin(_time * 8.0) * 0.3
	mesh.scale = Vector3(1.0 + absf(flap) * 0.2, 1.0, 1.0 - absf(flap) * 0.1)


func _process_hovering(delta: float) -> void:
	# Patrol back and forth at hover height
	velocity.x = patrol_speed * _patrol_direction
	velocity.y = 0.0
	velocity.z = 0.0

	# Gentle bob
	global_position.y = _hover_position.y + sin(_time * 2.0) * 0.3

	var distance_from_start := global_position.x - _hover_position.x
	if absf(distance_from_start) >= patrol_distance:
		_patrol_direction *= -1.0

	# Detect player
	if _player:
		var dist := global_position.distance_to(_player.global_position)
		if dist < detect_range:
			_start_swoop()


func _start_swoop() -> void:
	_state = BatState.SWOOPING
	if _player:
		_swoop_target = _player.global_position + Vector3(0, 0.5, 0)
	AudioManager.play_sfx_random_pitch(SoundLibrary.bat_screech)


func _process_swooping(delta: float) -> void:
	var dir := (_swoop_target - global_position).normalized()
	velocity = dir * swoop_speed

	# Check if we reached the target or passed it
	var dist := global_position.distance_to(_swoop_target)
	if dist < 1.0:
		_state = BatState.RETURNING
		AudioManager.play_sfx(SoundLibrary.bat_swoop)


func _process_returning(delta: float) -> void:
	var dir := (_hover_position - global_position).normalized()
	velocity = dir * return_speed

	var dist := global_position.distance_to(_hover_position)
	if dist < 0.5:
		global_position = _hover_position
		velocity = Vector3.ZERO
		_state = BatState.HOVERING


func _on_player_contact(body: Node3D) -> void:
	_damage_player(body)


func _die(from_position: Vector3) -> void:
	_is_dead = true
	died.emit()
	Particles.spawn_bat_death(global_position + Vector3(0, 0.3, 0))
	ScreenShake.shake_light()
	AudioManager.play_sfx(SoundLibrary.enemy_death)

	collision_shape.set_deferred("disabled", true)
	hurtbox.set_deferred("monitoring", false)

	var dir := (global_position - from_position).normalized()
	dir.y = 0.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh, "scale", Vector3(1.5, 0.2, 1.5), 0.1)
	tween.tween_property(self, "position",
		position + Vector3(dir.x * knockback_on_death, 3.0, dir.z * knockback_on_death),
		0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(mesh, "rotation:x", TAU * 2, 0.4)
	tween.chain().tween_property(mesh, "scale", Vector3.ZERO, 0.15)
	tween.chain().tween_callback(queue_free)
