extends Node3D

## Third-person follow camera for 3D platformer.
## Uses SpringArm3D for collision avoidance.
## Features: smooth follow, look-ahead, manual rotation, jump zoom-out.

@export var target_path: NodePath

# Follow settings
@export var follow_speed: float = 8.0
@export var follow_offset: Vector3 = Vector3(0.0, 2.0, 0.0)  # Offset from target

# Orbit settings
@export var default_distance: float = 8.0
@export var min_distance: float = 4.0
@export var max_distance: float = 12.0
@export var orbit_speed: float = 2.0
@export var pitch_speed: float = 1.5
@export var pitch_angle: float = -20.0  # Degrees, negative = looking down
@export var min_pitch: float = -60.0
@export var max_pitch: float = 10.0

# Look-ahead
@export var look_ahead_distance: float = 2.0
@export var look_ahead_speed: float = 4.0

# Jump zoom-out
@export var jump_zoom_distance: float = 10.0
@export var jump_zoom_speed: float = 3.0

# Internal state
var _target: Node3D = null
var _yaw: float = 0.0  # Horizontal rotation in radians
var _current_distance: float = 8.0
var _look_ahead_offset: Vector3 = Vector3.ZERO
var _target_look_ahead: Vector3 = Vector3.ZERO

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	if target_path:
		_target = get_node(target_path)
	_current_distance = default_distance
	spring_arm.spring_length = _current_distance

	# Start camera behind target
	if _target:
		global_position = _target.global_position + follow_offset
		_yaw = _target.rotation.y


func _physics_process(delta: float) -> void:
	if not _target:
		return

	_handle_camera_input(delta)
	_update_look_ahead(delta)
	_update_distance(delta)
	_update_position(delta)
	_update_rotation()


func _handle_camera_input(delta: float) -> void:
	var camera_input := Input.get_action_strength("camera_right") - Input.get_action_strength("camera_left")
	_yaw -= camera_input * orbit_speed * delta

	# Vertical pitch control (camera_up looks up = increase pitch, camera_down looks down)
	var pitch_input := Input.get_action_strength("camera_up") - Input.get_action_strength("camera_down")
	pitch_angle += pitch_input * pitch_speed * delta * 60.0  # Scale to feel consistent
	pitch_angle = clampf(pitch_angle, min_pitch, max_pitch)


func _update_look_ahead(delta: float) -> void:
	if not _target is CharacterBody3D:
		return

	var char_body := _target as CharacterBody3D
	var horizontal_vel := Vector3(char_body.velocity.x, 0.0, char_body.velocity.z)

	if horizontal_vel.length() > 0.5:
		_target_look_ahead = horizontal_vel.normalized() * look_ahead_distance
	else:
		_target_look_ahead = Vector3.ZERO

	_look_ahead_offset = _look_ahead_offset.lerp(_target_look_ahead, look_ahead_speed * delta)


func _update_distance(delta: float) -> void:
	var target_distance := default_distance

	if _target is CharacterBody3D:
		var char_body := _target as CharacterBody3D
		# Zoom out when player is airborne and falling
		if not char_body.is_on_floor() and char_body.velocity.y < -2.0:
			target_distance = jump_zoom_distance

	_current_distance = lerp(_current_distance, target_distance, jump_zoom_speed * delta)
	_current_distance = clampf(_current_distance, min_distance, max_distance)
	spring_arm.spring_length = _current_distance

	# During wall run, disable spring arm collision so the wall doesn't push the camera in
	if _target is CharacterBody3D:
		var char_body := _target as CharacterBody3D
		if "current_state" in char_body and char_body.current_state == char_body.State.WALL_RUNNING:
			spring_arm.spring_length = default_distance
			spring_arm.collision_mask = 0
		else:
			spring_arm.collision_mask = 2


func _update_position(delta: float) -> void:
	var target_pos := _target.global_position + follow_offset + _look_ahead_offset
	global_position = global_position.lerp(target_pos, follow_speed * delta)


func _update_rotation() -> void:
	# Apply yaw (horizontal orbit)
	spring_arm.rotation.y = _yaw
	# Apply pitch (vertical angle)
	spring_arm.rotation.x = deg_to_rad(pitch_angle)
