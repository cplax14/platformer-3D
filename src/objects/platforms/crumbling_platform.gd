extends StaticBody3D

## Crumbling platform — shakes when stepped on, then falls after a delay.
## Respawns after a cooldown.

@export var shake_duration: float = 0.8
@export var fall_speed: float = 15.0
@export var respawn_time: float = 3.0

var _original_position: Vector3
var _is_shaking: bool = false
var _is_falling: bool = false
var _shake_timer: float = 0.0
var _respawn_timer: float = 0.0
var _triggered: bool = false

@onready var detection_area: Area3D = $DetectionArea
@onready var mesh: CSGBox3D = $CSGBox3D
@onready var collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	_original_position = position
	detection_area.body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _is_shaking:
		_shake_timer -= delta
		# Shake effect
		var shake_offset := Vector3(
			randf_range(-0.05, 0.05),
			randf_range(-0.02, 0.02),
			randf_range(-0.05, 0.05)
		)
		position = _original_position + shake_offset

		if _shake_timer <= 0.0:
			_is_shaking = false
			_is_falling = true

	elif _is_falling:
		position.y -= fall_speed * delta
		if position.y < _original_position.y - 20.0:
			_start_respawn()

	elif _respawn_timer > 0.0:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()


func _on_body_entered(body: Node3D) -> void:
	if _triggered:
		return
	if not body is CharacterBody3D:
		return

	_triggered = true
	_is_shaking = true
	_shake_timer = shake_duration


func _start_respawn() -> void:
	_is_falling = false
	visible = false
	collision.disabled = true
	_respawn_timer = respawn_time


func _respawn() -> void:
	position = _original_position
	visible = true
	collision.disabled = false
	_triggered = false
