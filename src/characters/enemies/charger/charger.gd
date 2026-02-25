extends BaseEnemy

## Charger — idles until player is in range, then charges at them. 2 HP.

enum ChargerState { IDLE, WINDUP, CHARGING, RECOVERING }

@export var detection_range: float = 10.0
@export var charge_speed: float = 12.0
@export var windup_time: float = 0.6
@export var charge_duration: float = 1.0
@export var recovery_time: float = 1.5
@export var idle_speed: float = 1.5
@export var patrol_distance: float = 3.0

var _state: ChargerState = ChargerState.IDLE
var _state_timer: float = 0.0
var _charge_direction: Vector3 = Vector3.ZERO
var _start_position: Vector3
var _patrol_direction: float = 1.0
var _player: CharacterBody3D = null

@onready var player_damage_area: Area3D = $PlayerDamageArea


func _enemy_ready() -> void:
	max_hp = 2
	hp = 2
	_start_position = global_position
	player_damage_area.body_entered.connect(_on_player_contact)


func _enemy_process(delta: float) -> void:
	_find_player()
	_state_timer -= delta

	match _state:
		ChargerState.IDLE:
			_process_idle(delta)
		ChargerState.WINDUP:
			_process_windup(delta)
		ChargerState.CHARGING:
			_process_charging(delta)
		ChargerState.RECOVERING:
			_process_recovering(delta)


func _process_idle(delta: float) -> void:
	# Simple patrol
	velocity.x = idle_speed * _patrol_direction
	velocity.z = 0.0

	var dist := global_position.x - _start_position.x
	if absf(dist) >= patrol_distance:
		_patrol_direction *= -1.0

	# Check for player
	if _player:
		var to_player := global_position.distance_to(_player.global_position)
		if to_player <= detection_range:
			_start_windup()


func _start_windup() -> void:
	_state = ChargerState.WINDUP
	_state_timer = windup_time
	velocity = Vector3.ZERO

	# Face the player
	if _player:
		_charge_direction = (_player.global_position - global_position)
		_charge_direction.y = 0.0
		_charge_direction = _charge_direction.normalized()

	# Visual telegraph: shake/pulse
	var tween := create_tween()
	tween.tween_property(mesh, "scale", Vector3(1.3, 0.7, 1.3), windup_time * 0.5)
	tween.tween_property(mesh, "scale", Vector3(0.8, 1.2, 0.8), windup_time * 0.5)


func _process_windup(_delta: float) -> void:
	velocity = Vector3.ZERO
	if _state_timer <= 0.0:
		_start_charge()


func _start_charge() -> void:
	_state = ChargerState.CHARGING
	_state_timer = charge_duration
	mesh.scale = Vector3.ONE


func _process_charging(_delta: float) -> void:
	velocity.x = _charge_direction.x * charge_speed
	velocity.z = _charge_direction.z * charge_speed

	# Face charge direction
	if _charge_direction.length() > 0.1:
		rotation.y = atan2(_charge_direction.x, _charge_direction.z)

	if _state_timer <= 0.0:
		_start_recovery()


func _start_recovery() -> void:
	_state = ChargerState.RECOVERING
	_state_timer = recovery_time
	velocity = Vector3.ZERO

	# Dizzy animation
	var tween := create_tween()
	tween.set_loops(3)
	tween.tween_property(mesh, "rotation:z", 0.2, 0.15)
	tween.tween_property(mesh, "rotation:z", -0.2, 0.15)
	tween.chain().tween_property(mesh, "rotation:z", 0.0, 0.1)


func _process_recovering(_delta: float) -> void:
	if _state_timer <= 0.0:
		_state = ChargerState.IDLE
		mesh.rotation.z = 0.0


func _find_player() -> void:
	if _player:
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0] as CharacterBody3D


func _on_player_contact(body: Node3D) -> void:
	_damage_player(body)
