extends CharacterBody3D

## Player controller for a kid-friendly 3D platformer.
## Handles movement, jumping (variable height, double jump, coyote time,
## jump buffering), ground pound, and spin attack.

# Movement
@export var move_speed: float = 8.0
@export var acceleration: float = 30.0
@export var deceleration: float = 40.0
@export var rotation_speed: float = 10.0

# Jumping
@export var jump_force: float = 12.0
@export var jump_cut_multiplier: float = 0.4  # Applied when releasing jump early
@export var double_jump_force: float = 10.0
@export var coyote_time: float = 0.15
@export var jump_buffer_time: float = 0.15

# Ground pound
@export var ground_pound_speed: float = 25.0
@export var ground_pound_jump_boost: float = 14.0

# Spin attack
@export var spin_attack_duration: float = 0.4
@export var spin_attack_cooldown: float = 0.6
@export var spin_attack_radius: float = 2.0

# Gravity
@export var gravity: float = 30.0
@export var max_fall_speed: float = 30.0

# References
@onready var mesh: MeshInstance3D = $Mesh
@onready var collision_shape: CollisionShape3D = $CollisionShape
@onready var spin_attack_area: Area3D = $SpinAttackArea
@onready var ground_pound_area: Area3D = $GroundPoundArea
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# State
enum State { IDLE, RUNNING, JUMPING, FALLING, DOUBLE_JUMPING, GROUND_POUND, SPIN_ATTACK }
var current_state: State = State.IDLE

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _has_double_jump: bool = true
var _is_ground_pounding: bool = false
var _spin_attack_timer: float = 0.0
var _spin_attack_cooldown_timer: float = 0.0
var _was_on_floor: bool = false
var _input_direction: Vector3 = Vector3.ZERO
var _last_movement_direction: Vector3 = Vector3.FORWARD


func _ready() -> void:
	add_to_group("player")
	spin_attack_area.monitoring = false
	ground_pound_area.monitoring = false

	# Apply toon material
	if mesh and MaterialLibrary:
		mesh.material_override = MaterialLibrary.get_material("player")


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_handle_input()
	_apply_gravity(delta)
	_handle_jump()
	_handle_ground_pound()
	_handle_spin_attack(delta)
	_apply_movement(delta)
	_update_state()

	_was_on_floor = is_on_floor()
	move_and_slide()


func _update_timers(delta: float) -> void:
	# Coyote time: allow jumping shortly after leaving a ledge
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	# Jump buffer: register jump input slightly before landing
	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

	# Spin attack cooldown
	if _spin_attack_cooldown_timer > 0.0:
		_spin_attack_cooldown_timer = maxf(_spin_attack_cooldown_timer - delta, 0.0)


func _handle_input() -> void:
	# Gather movement input relative to camera
	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	)

	# Transform input relative to camera orientation
	var camera := get_viewport().get_camera_3d()
	if camera:
		var cam_basis := camera.global_basis
		var forward := -cam_basis.z
		var right := cam_basis.x
		forward.y = 0.0
		right.y = 0.0
		forward = forward.normalized()
		right = right.normalized()
		_input_direction = (right * input_dir.x + forward * input_dir.y).normalized()
	else:
		_input_direction = Vector3(input_dir.x, 0.0, input_dir.y).normalized()

	if _input_direction.length() > 0.1:
		_last_movement_direction = _input_direction

	# Jump buffer
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time


func _apply_gravity(delta: float) -> void:
	if _is_ground_pounding:
		velocity.y = -ground_pound_speed
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
		velocity.y = maxf(velocity.y, -max_fall_speed)

		# Variable jump height: cut upward velocity when releasing jump
		if velocity.y > 0.0 and not Input.is_action_pressed("jump"):
			velocity.y *= jump_cut_multiplier


func _handle_jump() -> void:
	if _is_ground_pounding or current_state == State.SPIN_ATTACK:
		return

	var can_coyote_jump := _coyote_timer > 0.0
	var wants_jump := _jump_buffer_timer > 0.0

	# Regular jump (with coyote time and jump buffer)
	if wants_jump and can_coyote_jump:
		_perform_jump(jump_force)
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0
		_has_double_jump = true
		return

	# Double jump
	if wants_jump and not is_on_floor() and _has_double_jump and _coyote_timer <= 0.0:
		_perform_jump(double_jump_force)
		_has_double_jump = false
		_jump_buffer_timer = 0.0

	# Reset double jump on landing
	if is_on_floor() and not _was_on_floor:
		_has_double_jump = true
		Juice.squash(mesh)
		Particles.spawn_land_impact(global_position)


func _perform_jump(force: float) -> void:
	velocity.y = force
	Juice.stretch(mesh)
	Particles.spawn_jump_dust(global_position)


func _handle_ground_pound() -> void:
	# Start ground pound: press attack while in air and not already pounding
	if not is_on_floor() and not _is_ground_pounding and current_state != State.SPIN_ATTACK:
		if Input.is_action_just_pressed("attack"):
			_start_ground_pound()
			return

	# Land from ground pound
	if _is_ground_pounding and is_on_floor():
		_end_ground_pound()


func _start_ground_pound() -> void:
	_is_ground_pounding = true
	velocity.x = 0.0
	velocity.z = 0.0
	velocity.y = 2.0  # Small hop before slamming down
	ground_pound_area.monitoring = true
	ground_pound_area.collision_layer = 1


func _end_ground_pound() -> void:
	_is_ground_pounding = false
	ground_pound_area.monitoring = false
	ground_pound_area.collision_layer = 0
	# Bounce after ground pound for fun feel
	velocity.y = ground_pound_jump_boost * 0.3
	Particles.spawn_ground_pound_impact(global_position)
	ScreenShake.shake_medium()
	Juice.squash(mesh, 0.5)


func _handle_spin_attack(delta: float) -> void:
	if _spin_attack_timer > 0.0:
		_spin_attack_timer -= delta
		if _spin_attack_timer <= 0.0:
			_end_spin_attack()
		return

	# Start spin attack: press attack while on ground and cooldown is ready
	if is_on_floor() and not _is_ground_pounding and _spin_attack_cooldown_timer <= 0.0:
		if Input.is_action_just_pressed("attack"):
			_start_spin_attack()


func _start_spin_attack() -> void:
	_spin_attack_timer = spin_attack_duration
	spin_attack_area.monitoring = true
	spin_attack_area.collision_layer = 1
	current_state = State.SPIN_ATTACK
	Particles.spawn_spin_attack(global_position + Vector3(0, 0.5, 0))
	_play_spin_animation()


func _play_spin_animation() -> void:
	var tween := create_tween()
	# Widen and flatten slightly to sell the spin
	tween.set_parallel(true)
	tween.tween_property(mesh, "scale", Vector3(1.4, 0.7, 1.4), 0.08).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh, "rotation:y", mesh.rotation.y + TAU * 2, spin_attack_duration).set_ease(Tween.EASE_OUT)
	# Return to normal scale after the initial squash
	tween.chain().tween_property(mesh, "scale", Vector3.ONE, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)


func _end_spin_attack() -> void:
	_spin_attack_timer = 0.0
	_spin_attack_cooldown_timer = spin_attack_cooldown
	spin_attack_area.monitoring = false
	spin_attack_area.collision_layer = 0


func _apply_movement(delta: float) -> void:
	if _is_ground_pounding:
		return  # No horizontal movement during ground pound

	var target_velocity := Vector3.ZERO

	if _input_direction.length() > 0.1:
		target_velocity = _input_direction * move_speed

		# Rotate player to face movement direction
		var target_rotation := atan2(_input_direction.x, _input_direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)

	# Smooth acceleration/deceleration (horizontal only)
	var accel := acceleration if _input_direction.length() > 0.1 else deceleration
	velocity.x = move_toward(velocity.x, target_velocity.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, accel * delta)


func _update_state() -> void:
	if current_state == State.SPIN_ATTACK and _spin_attack_timer > 0.0:
		return  # Don't interrupt spin attack

	if _is_ground_pounding:
		current_state = State.GROUND_POUND
	elif is_on_floor():
		if _input_direction.length() > 0.1:
			current_state = State.RUNNING
		else:
			current_state = State.IDLE
	elif velocity.y > 0.0:
		if _has_double_jump:
			current_state = State.JUMPING
		else:
			current_state = State.DOUBLE_JUMPING
	else:
		current_state = State.FALLING


# Called by enemies/hazards to damage the player
func take_damage(damage_position: Vector3) -> void:
	# Knockback away from damage source
	var knockback_dir := (global_position - damage_position).normalized()
	knockback_dir.y = 0.0
	velocity = knockback_dir * 6.0
	velocity.y = 6.0

	# Cancel any active states
	_is_ground_pounding = false
	_spin_attack_timer = 0.0
	spin_attack_area.monitoring = false
	spin_attack_area.collision_layer = 0
	ground_pound_area.monitoring = false
	ground_pound_area.collision_layer = 0

	# Juice
	ScreenShake.shake_light()
	Juice.flash(mesh)
