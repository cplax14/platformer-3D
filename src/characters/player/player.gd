extends CharacterBody3D

## Player controller for a kid-friendly 3D platformer.
## Handles movement, jumping (variable height, double jump, coyote time,
## jump buffering), ground pound, spin attack, wall run, and air dash.

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

# Wall run
@export var wall_run_speed: float = 8.0
@export var wall_run_duration: float = 0.6
@export var wall_jump_force: float = 10.0
@export var wall_jump_horizontal: float = 7.0

# Spin attack
@export var spin_attack_duration: float = 0.4
@export var spin_attack_cooldown: float = 0.6
@export var spin_attack_radius: float = 2.0

# Air dash
@export var dash_speed: float = 20.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.4

# Wall slide
@export var wall_slide_speed: float = 3.0
@export var wall_slide_jump_force: float = 9.0
@export var wall_slide_jump_horizontal: float = 6.0

# Ground slide
@export var slide_speed: float = 12.0
@export var slide_duration: float = 0.5
@export var slide_deceleration: float = 20.0
@export var slide_jump_boost: float = 2.0

# Grapple
@export var grapple_range: float = 15.0
@export var grapple_pull_speed: float = 18.0
@export var grapple_arrive_distance: float = 1.5
@export var grapple_release_boost: float = 3.0

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
enum State { IDLE, RUNNING, JUMPING, FALLING, DOUBLE_JUMPING, GROUND_POUND, SPIN_ATTACK, WALL_RUNNING, DASHING, WALL_SLIDING, SLIDING, GRAPPLING }
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
var _is_wall_running: bool = false
var _wall_run_timer: float = 0.0
var _wall_normal: Vector3 = Vector3.ZERO
var _wall_run_used: bool = false

# Dash state
var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: Vector3 = Vector3.ZERO
var _has_air_dash: bool = true

# Wall slide state
var _is_wall_sliding: bool = false
var _wall_slide_normal: Vector3 = Vector3.ZERO

# Ground slide state
var _is_sliding: bool = false
var _slide_timer: float = 0.0
var _slide_direction: Vector3 = Vector3.ZERO

# Grapple state
var _is_grappling: bool = false
var _grapple_target: Node3D = null
var _nearest_anchor: Node3D = null
var _grapple_rope_mesh: MeshInstance3D = null
var _grapple_rope_material: StandardMaterial3D = null
var _post_grapple_jump: bool = false  # Gives an extra jump after grapple ends

# Animation time accumulator
var _anim_time: float = 0.0

# Robot parts for procedural animation
var _robot_head: MeshInstance3D
var _robot_body: MeshInstance3D
var _robot_eye_l: MeshInstance3D
var _robot_eye_r: MeshInstance3D
var _robot_arm_l: MeshInstance3D
var _robot_arm_r: MeshInstance3D
var _robot_leg_l: MeshInstance3D
var _robot_leg_r: MeshInstance3D
var _robot_antenna_pole: MeshInstance3D
var _robot_antenna_tip: MeshInstance3D


func _ready() -> void:
	add_to_group("player")
	spin_attack_area.monitoring = false
	ground_pound_area.monitoring = false

	_build_robot_mesh()


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_handle_input()
	_apply_gravity(delta)
	_handle_jump()
	_handle_wall_run(delta)
	_handle_wall_slide(delta)
	_handle_dash(delta)
	_handle_grapple(delta)
	_handle_ground_pound()
	_handle_spin_attack(delta)
	_handle_ground_slide(delta)
	_apply_movement(delta)
	_update_state()
	_animate_robot(delta)

	_was_on_floor = is_on_floor()
	move_and_slide()


func _update_timers(delta: float) -> void:
	# Coyote time: allow jumping shortly after leaving a ledge
	var effective_coyote := 0.4 if GameManager.get_assist("assist_coyote") else coyote_time
	if is_on_floor():
		_coyote_timer = effective_coyote
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	# Jump buffer: register jump input slightly before landing
	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

	# Spin attack cooldown
	if _spin_attack_cooldown_timer > 0.0:
		_spin_attack_cooldown_timer = maxf(_spin_attack_cooldown_timer - delta, 0.0)

	# Dash cooldown
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)


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

	if _is_wall_running or _is_dashing or _is_grappling:
		return

	if not is_on_floor():
		var effective_gravity := 18.0 if GameManager.get_assist("assist_slow_fall") else gravity
		var effective_max_fall := 15.0 if GameManager.get_assist("assist_slow_fall") else max_fall_speed
		velocity.y -= effective_gravity * delta
		velocity.y = maxf(velocity.y, -effective_max_fall)

		# Variable jump height: cut upward velocity when releasing jump
		if velocity.y > 0.0 and not Input.is_action_pressed("jump"):
			velocity.y *= jump_cut_multiplier


func _handle_jump() -> void:
	if _is_ground_pounding or current_state == State.SPIN_ATTACK or _is_wall_running or _is_dashing or _is_wall_sliding or _is_grappling:
		return

	var can_coyote_jump := _coyote_timer > 0.0
	var wants_jump := _jump_buffer_timer > 0.0

	# Regular jump (with coyote time and jump buffer)
	if wants_jump and can_coyote_jump:
		_perform_jump(jump_force)
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0
		_has_double_jump = true
		AudioManager.play_sfx(SoundLibrary.jump)
		return

	# Double jump (or post-grapple first jump)
	if wants_jump and not is_on_floor() and _has_double_jump and _coyote_timer <= 0.0:
		_perform_jump(double_jump_force)
		if _post_grapple_jump:
			# First jump after grapple — acts like a "first jump", keep double jump available
			_post_grapple_jump = false
		elif not GameManager.get_assist("assist_inf_jumps"):
			_has_double_jump = false
		_jump_buffer_timer = 0.0
		AudioManager.play_sfx(SoundLibrary.double_jump)

	# Reset double jump, wall run, and air dash on landing
	if is_on_floor() and not _was_on_floor:
		_has_double_jump = true
		_post_grapple_jump = false
		_wall_run_used = false
		_has_air_dash = true
		Juice.squash(mesh)
		Particles.spawn_land_impact(global_position)
		AudioManager.play_sfx(SoundLibrary.land)


func _perform_jump(force: float) -> void:
	velocity.y = force
	Juice.stretch(mesh)
	Particles.spawn_jump_dust(global_position)


func _handle_wall_run(delta: float) -> void:
	if not GameManager.is_ability_unlocked("wall_run"):
		return

	# While wall running
	if _is_wall_running:
		_wall_run_timer -= delta

		# Wall jump: press jump during wall run
		if Input.is_action_just_pressed("jump"):
			_end_wall_run()
			velocity = _wall_normal * wall_jump_horizontal + Vector3.UP * wall_jump_force
			_has_double_jump = true
			_has_air_dash = true  # Reset air dash on wall jump
			_wall_run_used = true
			_jump_buffer_timer = 0.0
			Juice.stretch(mesh)
			Particles.spawn_jump_dust(global_position)
			AudioManager.play_sfx(SoundLibrary.wall_jump)
			return

		# Timeout: wall run expired
		if _wall_run_timer <= 0.0:
			_end_wall_run()
			return

		# Move upward along wall
		velocity.y = wall_run_speed
		# Slight forward movement along the wall surface
		var wall_tangent := Vector3.UP.cross(_wall_normal).normalized()
		if _input_direction.dot(wall_tangent) < 0.0:
			wall_tangent = -wall_tangent
		velocity.x = wall_tangent.x * move_speed * 0.3
		velocity.z = wall_tangent.z * move_speed * 0.3

		# Continuous dust particles
		if Engine.get_physics_frames() % 4 == 0:
			Particles.spawn_wall_run_dust(global_position, _wall_normal)
		# Bright sparkle trail alongside dust
		if Engine.get_physics_frames() % 3 == 0:
			Particles.spawn_wall_run_sparkle(global_position, _wall_normal)
		return

	# Entry: airborne, on wall, pressing toward wall, jump pressed, not used yet
	if is_on_floor() or _is_ground_pounding or _wall_run_used or _is_dashing or _is_wall_sliding:
		return
	if current_state == State.SPIN_ATTACK:
		return
	if not is_on_wall():
		return

	_wall_normal = get_wall_normal()
	# Check player is pressing toward the wall (generous angle for kids)
	var wall_threshold := 0.0 if GameManager.get_assist("assist_wall_angles") else 0.3
	var pressing_toward_wall := _input_direction.dot(-_wall_normal) > wall_threshold
	if not pressing_toward_wall:
		return

	if Input.is_action_just_pressed("jump") or _jump_buffer_timer > 0.0:
		_start_wall_run()


func _start_wall_run() -> void:
	_is_wall_running = true
	_wall_run_timer = wall_run_duration
	_jump_buffer_timer = 0.0
	current_state = State.WALL_RUNNING
	# Tilt mesh toward wall
	Juice.wall_tilt(mesh, -_wall_normal)
	Juice.squash(mesh, 0.2)
	ScreenShake.shake_light()
	Particles.spawn_wall_run_dust(global_position, _wall_normal)
	Particles.spawn_wall_run_sparkle(global_position, _wall_normal)
	AudioManager.play_sfx(SoundLibrary.wall_run_start)


func _end_wall_run() -> void:
	_is_wall_running = false
	_wall_run_timer = 0.0
	# Reset mesh tilt
	Juice.wall_tilt_reset(mesh)


func _handle_wall_slide(delta: float) -> void:
	if not GameManager.is_ability_unlocked("wall_slide"):
		return

	# While wall sliding
	if _is_wall_sliding:
		# Wall jump from slide
		if Input.is_action_just_pressed("jump"):
			_end_wall_slide()
			velocity = _wall_slide_normal * wall_slide_jump_horizontal + Vector3.UP * wall_slide_jump_force
			_has_double_jump = true
			_has_air_dash = true
			_jump_buffer_timer = 0.0
			Juice.stretch(mesh)
			Particles.spawn_jump_dust(global_position)
			AudioManager.play_sfx(SoundLibrary.wall_jump)
			return

		# Exit: left wall, landed, or started wall run
		if is_on_floor() or not is_on_wall() or _is_wall_running:
			_end_wall_slide()
			return

		# Cap descent speed
		velocity.y = maxf(velocity.y, -wall_slide_speed)

		# Dust particles (every 6 frames)
		if Engine.get_physics_frames() % 6 == 0:
			Particles.spawn_wall_run_dust(global_position, _wall_slide_normal)
		# Sparkle particles during wall slide
		if Engine.get_physics_frames() % 4 == 0:
			Particles.spawn_wall_run_sparkle(global_position, _wall_slide_normal)
		return

	# Entry: airborne, falling, on wall, not in other states
	if is_on_floor() or _is_ground_pounding or _is_dashing or _is_wall_running:
		return
	if current_state == State.SPIN_ATTACK:
		return
	if not is_on_wall() or velocity.y >= 0.0:
		return

	_start_wall_slide()


func _start_wall_slide() -> void:
	_is_wall_sliding = true
	_wall_slide_normal = get_wall_normal()
	current_state = State.WALL_SLIDING
	AudioManager.play_sfx(SoundLibrary.wall_slide)


func _end_wall_slide() -> void:
	_is_wall_sliding = false
	_wall_slide_normal = Vector3.ZERO


func _handle_dash(delta: float) -> void:
	if not GameManager.is_ability_unlocked("dash"):
		return

	# During dash
	if _is_dashing:
		_dash_timer -= delta
		velocity = _dash_direction * dash_speed
		velocity.y = 0.0  # Keep horizontal

		# Dash trail particles + speed lines
		if Engine.get_physics_frames() % 2 == 0:
			Particles.spawn_dash_trail(global_position, _dash_direction)
			Particles.spawn_dash_speed_lines(global_position, _dash_direction)

		if _dash_timer <= 0.0:
			_end_dash()
		return

	# Entry: press dash while airborne, has air dash, cooldown ready
	if not Input.is_action_just_pressed("dash"):
		return
	if is_on_floor() or not _has_air_dash or _dash_cooldown_timer > 0.0:
		return
	if _is_ground_pounding or _is_wall_running or current_state == State.SPIN_ATTACK:
		return

	_start_dash()


func _start_dash() -> void:
	if _is_wall_sliding:
		_end_wall_slide()
	_is_dashing = true
	_has_air_dash = false
	_dash_timer = dash_duration

	# Dash in the direction the player is facing/moving
	if _input_direction.length() > 0.1:
		_dash_direction = _input_direction.normalized()
	else:
		_dash_direction = _last_movement_direction.normalized()

	# VFX and SFX
	Juice.stretch(mesh, 0.4)
	AudioManager.play_sfx(SoundLibrary.dash)
	Particles.spawn_dash_trail(global_position, _dash_direction)


func _end_dash() -> void:
	_is_dashing = false
	_dash_timer = 0.0
	_dash_cooldown_timer = dash_cooldown
	# Preserve some forward momentum after dash
	velocity = _dash_direction * move_speed * 0.6
	velocity.y = 0.0


func _handle_ground_pound() -> void:
	if _is_dashing or _is_grappling:
		return

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
	AudioManager.play_sfx(SoundLibrary.ground_pound)


func _handle_spin_attack(delta: float) -> void:
	if _is_dashing or _is_grappling:
		return

	if _spin_attack_timer > 0.0:
		_spin_attack_timer -= delta
		# Expanding ring particles during entire spin
		if Engine.get_physics_frames() % 4 == 0:
			Particles.spawn_spin_ring(global_position + Vector3(0, 0.5, 0))
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
	AudioManager.play_sfx(SoundLibrary.spin_attack)
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


func _handle_ground_slide(delta: float) -> void:
	# During slide
	if _is_sliding:
		_slide_timer -= delta

		# Slide-jump: jump during slide for boosted horizontal momentum
		if Input.is_action_just_pressed("jump"):
			var slide_dir := _slide_direction.normalized()
			_end_ground_slide()
			_perform_jump(jump_force)
			velocity.x += slide_dir.x * slide_jump_boost
			velocity.z += slide_dir.z * slide_jump_boost
			_coyote_timer = 0.0
			_jump_buffer_timer = 0.0
			_has_double_jump = true
			AudioManager.play_sfx(SoundLibrary.jump)
			return

		# Exit: timer expired or left floor
		if _slide_timer <= 0.0 or not is_on_floor():
			_end_ground_slide()
			return

		# Decelerate slide
		var speed := _slide_direction.length()
		var new_speed := maxf(speed - slide_deceleration * delta, 0.0)
		if new_speed > 0.0:
			_slide_direction = _slide_direction.normalized() * new_speed
		else:
			_end_ground_slide()
			return

		velocity.x = _slide_direction.x
		velocity.z = _slide_direction.z

		# Dust trail
		if Engine.get_physics_frames() % 3 == 0:
			Particles.spawn_slide_dust(global_position, _slide_direction.normalized())
		return

	# Entry: crouch pressed, on floor, moving, not in other states
	if not Input.is_action_just_pressed("crouch"):
		return
	if not is_on_floor() or _is_ground_pounding or _is_dashing:
		return
	if current_state == State.SPIN_ATTACK:
		return
	if _input_direction.length() <= 0.1:
		return

	_start_ground_slide()


func _start_ground_slide() -> void:
	_is_sliding = true
	_slide_timer = slide_duration
	_slide_direction = _input_direction.normalized() * slide_speed
	current_state = State.SLIDING
	Juice.squash(mesh, 0.4)
	AudioManager.play_sfx(SoundLibrary.slide)
	Particles.spawn_slide_dust(global_position, _input_direction.normalized())


func _end_ground_slide() -> void:
	_is_sliding = false
	_slide_timer = 0.0
	_slide_direction = Vector3.ZERO
	# Restore mesh scale
	var tween := mesh.create_tween()
	tween.tween_property(mesh, "scale", Vector3.ONE, 0.1).set_ease(Tween.EASE_OUT)


func _apply_movement(delta: float) -> void:
	if _is_ground_pounding or _is_wall_running or _is_dashing or _is_sliding or _is_grappling:
		return  # No horizontal input during ground pound, wall run, dash, slide, or grapple

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
	if _is_wall_running:
		current_state = State.WALL_RUNNING
		return
	if _is_grappling:
		current_state = State.GRAPPLING
		return
	if _is_dashing:
		current_state = State.DASHING
		return
	if _is_wall_sliding:
		current_state = State.WALL_SLIDING
		return
	if _is_sliding:
		current_state = State.SLIDING
		return

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
	if _is_wall_running:
		_end_wall_run()
	if _is_wall_sliding:
		_end_wall_slide()
	if _is_dashing:
		_end_dash()
	if _is_sliding:
		_end_ground_slide()
	if _is_grappling:
		_end_grapple("damage")
	spin_attack_area.monitoring = false
	spin_attack_area.collision_layer = 0
	ground_pound_area.monitoring = false
	ground_pound_area.collision_layer = 0

	# Juice and SFX
	ScreenShake.shake_light()
	Juice.flash(mesh)
	AudioManager.play_sfx(SoundLibrary.hurt)


func _handle_grapple(delta: float) -> void:
	if not GameManager.is_ability_unlocked("grapple"):
		return

	# During grapple
	if _is_grappling:
		if not is_instance_valid(_grapple_target):
			_end_grapple("damage")
			return

		var target_pos := _grapple_target.global_position
		var direction := (target_pos - global_position).normalized()
		var distance := global_position.distance_to(target_pos)

		# Release via jump
		if Input.is_action_just_pressed("jump"):
			_has_double_jump = true
			_has_air_dash = true
			_post_grapple_jump = true
			# Clear jump buffer so it doesn't immediately consume the double jump
			_jump_buffer_timer = 0.0
			_coyote_timer = 0.0
			_end_grapple("jump_release")
			return

		# Arrival
		if distance < grapple_arrive_distance:
			velocity = Vector3.UP * grapple_release_boost
			_has_double_jump = true
			_has_air_dash = true
			_post_grapple_jump = true
			# Clear coyote timer so next jump is treated as double jump, not coyote
			_coyote_timer = 0.0
			_jump_buffer_timer = 0.0
			_end_grapple("arrival")
			return

		# Pull toward target
		velocity = direction * grapple_pull_speed

		# Update rope visual
		_update_grapple_rope()

		# Trail particles
		if Engine.get_physics_frames() % 3 == 0:
			Particles.spawn_grapple_trail(global_position, direction)
		return

	# Targeting: find nearest anchor
	var prev_anchor := _nearest_anchor
	_nearest_anchor = _find_nearest_anchor()

	# Update anchor visual states
	if prev_anchor != _nearest_anchor:
		if is_instance_valid(prev_anchor) and prev_anchor.has_method("set_anchor_state"):
			prev_anchor.set_anchor_state(0)  # IDLE
		if is_instance_valid(_nearest_anchor) and _nearest_anchor.has_method("set_anchor_state"):
			_nearest_anchor.set_anchor_state(1)  # TARGETED
			if Engine.get_physics_frames() % 8 == 0:
				Particles.spawn_anchor_targeted(_nearest_anchor.global_position)

	# Entry: press grapple when target exists
	if not Input.is_action_just_pressed("grapple"):
		return
	if _nearest_anchor == null:
		return
	if _is_ground_pounding or _is_wall_running or _is_dashing or _is_wall_sliding or _is_sliding:
		return
	if current_state == State.SPIN_ATTACK:
		return

	_start_grapple()


func _start_grapple() -> void:
	_grapple_target = _nearest_anchor
	_is_grappling = true

	# Cancel conflicting states
	if _is_ground_pounding:
		_is_ground_pounding = false
		ground_pound_area.monitoring = false
		ground_pound_area.collision_layer = 0
	if _is_wall_running:
		_end_wall_run()
	if _is_wall_sliding:
		_end_wall_slide()
	if _is_dashing:
		_end_dash()
	if _is_sliding:
		_end_ground_slide()
	if _spin_attack_timer > 0.0:
		_end_spin_attack()

	# Set anchor to active state
	if _grapple_target.has_method("set_anchor_state"):
		_grapple_target.set_anchor_state(2)  # ACTIVE

	# Create rope visual
	_create_grapple_rope()

	# VFX and SFX
	var direction := (_grapple_target.global_position - global_position).normalized()
	Particles.spawn_grapple_launch(global_position, direction)
	AudioManager.play_sfx(SoundLibrary.grapple_fire)
	Juice.stretch(mesh, 0.3)


func _end_grapple(release_type: String) -> void:
	_is_grappling = false

	# Reset anchor state
	if is_instance_valid(_grapple_target) and _grapple_target.has_method("set_anchor_state"):
		_grapple_target.set_anchor_state(0)  # IDLE
	_grapple_target = null

	# Destroy rope
	_destroy_grapple_rope()

	# VFX and SFX based on release type
	match release_type:
		"jump_release":
			Particles.spawn_grapple_release(global_position)
			AudioManager.play_sfx(SoundLibrary.grapple_release)
		"arrival":
			Particles.spawn_grapple_arrive(global_position)
			AudioManager.play_sfx(SoundLibrary.grapple_arrive)
			Juice.squash(mesh)
		"damage":
			pass  # Damage already has its own VFX


func _find_nearest_anchor() -> Node3D:
	var anchors := get_tree().get_nodes_in_group("grapple_anchor")
	var best_anchor: Node3D = null
	var best_score := -1.0

	# Get camera forward direction for facing bias
	var camera := get_viewport().get_camera_3d()
	var cam_forward := -camera.global_basis.z if camera else -global_basis.z
	cam_forward.y = 0.0
	cam_forward = cam_forward.normalized()

	for anchor in anchors:
		if not is_instance_valid(anchor):
			continue
		var dist := global_position.distance_to(anchor.global_position)
		if dist > grapple_range:
			continue

		# Line-of-sight check
		var space_state := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(
			global_position + Vector3(0, 0.5, 0),
			anchor.global_position,
			2  # Environment layer only
		)
		query.exclude = [get_rid()]
		var result := space_state.intersect_ray(query)
		if not result.is_empty():
			continue

		# Score: combine distance and facing direction
		# Normalize distance: closer = higher score (0 to 1)
		var dist_score := 1.0 - (dist / grapple_range)

		# Facing score: dot product with camera forward (-1 to 1), remap to 0-1
		var to_anchor: Vector3 = (anchor.global_position - global_position).normalized()
		var to_anchor_flat := Vector3(to_anchor.x, 0.0, to_anchor.z).normalized()
		var facing_dot := cam_forward.dot(to_anchor_flat)
		var facing_score := (facing_dot + 1.0) * 0.5  # Remap -1..1 to 0..1

		# Weight facing more heavily than distance so forward anchors are preferred
		var score := dist_score * 0.3 + facing_score * 0.7

		if score > best_score:
			best_score = score
			best_anchor = anchor

	return best_anchor


func _create_grapple_rope() -> void:
	_grapple_rope_mesh = MeshInstance3D.new()
	_grapple_rope_mesh.mesh = ImmediateMesh.new()

	_grapple_rope_material = StandardMaterial3D.new()
	_grapple_rope_material.albedo_color = Color(0.1, 0.15, 0.2, 1.0)
	_grapple_rope_material.emission_enabled = true
	_grapple_rope_material.emission = Color(0.15, 0.4, 0.5)
	_grapple_rope_material.emission_energy_multiplier = 1.0
	_grapple_rope_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_grapple_rope_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	get_tree().current_scene.add_child(_grapple_rope_mesh)


func _update_grapple_rope() -> void:
	if not _grapple_rope_mesh or not is_instance_valid(_grapple_target):
		return

	var im: ImmediateMesh = _grapple_rope_mesh.mesh
	im.clear_surfaces()

	var start_pos := _robot_arm_r.global_position if _robot_arm_r else global_position + Vector3(0.35, 0.55, 0)
	var end_pos := _grapple_target.global_position

	# Slight sag via bezier midpoint
	var mid := (start_pos + end_pos) * 0.5
	mid.y -= 0.4

	# Build a tube mesh (triangle strip) for visible thickness
	var camera := get_viewport().get_camera_3d()
	var rope_radius := 0.06
	var segments := 10

	# Compute bezier points
	var points: Array[Vector3] = []
	for i in range(segments + 1):
		var t := float(i) / segments
		var point := (1.0 - t) * (1.0 - t) * start_pos + 2.0 * (1.0 - t) * t * mid + t * t * end_pos
		points.append(point)

	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _grapple_rope_material)
	for i in range(points.size()):
		# Get tangent direction along the rope
		var tangent: Vector3
		if i < points.size() - 1:
			tangent = (points[i + 1] - points[i]).normalized()
		else:
			tangent = (points[i] - points[i - 1]).normalized()

		# Get camera-facing perpendicular to create billboard tube
		var cam_dir := Vector3.UP
		if camera:
			cam_dir = (camera.global_position - points[i]).normalized()
		var side := tangent.cross(cam_dir).normalized() * rope_radius

		# Two vertices per segment forming a ribbon
		im.surface_add_vertex(points[i] + side)
		im.surface_add_vertex(points[i] - side)
	im.surface_end()


func _destroy_grapple_rope() -> void:
	if _grapple_rope_mesh and is_instance_valid(_grapple_rope_mesh):
		_grapple_rope_mesh.queue_free()
	_grapple_rope_mesh = null
	_grapple_rope_material = null


func _build_robot_mesh() -> void:
	# Remove the default capsule mesh from $Mesh
	if mesh.mesh:
		mesh.mesh = null
	mesh.material_override = null

	var color_key := "player_" + GameManager.selected_color if GameManager.selected_color != "blue" else "player"
	var player_mat: ShaderMaterial = MaterialLibrary.get_material(color_key)
	var white_mat := StandardMaterial3D.new()
	white_mat.albedo_color = Color(0.95, 0.95, 1.0)
	white_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Body (torso)
	_robot_body = MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.5, 0.6, 0.4)
	_robot_body.mesh = body_mesh
	_robot_body.material_override = player_mat
	_robot_body.position = Vector3(0, 0.55, 0)
	mesh.add_child(_robot_body)

	# Head
	_robot_head = MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.2
	head_mesh.height = 0.4
	_robot_head.mesh = head_mesh
	_robot_head.material_override = player_mat
	_robot_head.position = Vector3(0, 1.05, 0)
	mesh.add_child(_robot_head)

	# Eyes
	_robot_eye_l = MeshInstance3D.new()
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.05
	eye_mesh.height = 0.1
	_robot_eye_l.mesh = eye_mesh
	_robot_eye_l.material_override = white_mat
	_robot_eye_l.position = Vector3(-0.08, 1.08, 0.16)
	mesh.add_child(_robot_eye_l)

	_robot_eye_r = MeshInstance3D.new()
	_robot_eye_r.mesh = eye_mesh
	_robot_eye_r.material_override = white_mat
	_robot_eye_r.position = Vector3(0.08, 1.08, 0.16)
	mesh.add_child(_robot_eye_r)

	# Left arm
	_robot_arm_l = MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.15, 0.4, 0.15)
	_robot_arm_l.mesh = arm_mesh
	_robot_arm_l.material_override = player_mat
	_robot_arm_l.position = Vector3(-0.35, 0.55, 0)
	mesh.add_child(_robot_arm_l)

	# Right arm
	_robot_arm_r = MeshInstance3D.new()
	_robot_arm_r.mesh = arm_mesh
	_robot_arm_r.material_override = player_mat
	_robot_arm_r.position = Vector3(0.35, 0.55, 0)
	mesh.add_child(_robot_arm_r)

	# Left leg
	_robot_leg_l = MeshInstance3D.new()
	var leg_mesh := BoxMesh.new()
	leg_mesh.size = Vector3(0.15, 0.35, 0.15)
	_robot_leg_l.mesh = leg_mesh
	_robot_leg_l.material_override = player_mat
	_robot_leg_l.position = Vector3(-0.12, 0.075, 0)
	mesh.add_child(_robot_leg_l)

	# Right leg
	_robot_leg_r = MeshInstance3D.new()
	_robot_leg_r.mesh = leg_mesh
	_robot_leg_r.material_override = player_mat
	_robot_leg_r.position = Vector3(0.12, 0.075, 0)
	mesh.add_child(_robot_leg_r)

	# Antenna pole
	_robot_antenna_pole = MeshInstance3D.new()
	var antenna_mesh := CylinderMesh.new()
	antenna_mesh.top_radius = 0.015
	antenna_mesh.bottom_radius = 0.015
	antenna_mesh.height = 0.2
	_robot_antenna_pole.mesh = antenna_mesh
	_robot_antenna_pole.material_override = player_mat
	_robot_antenna_pole.position = Vector3(0, 1.35, 0)
	mesh.add_child(_robot_antenna_pole)

	# Antenna tip (glowing ball)
	_robot_antenna_tip = MeshInstance3D.new()
	var tip_mesh := SphereMesh.new()
	tip_mesh.radius = 0.04
	tip_mesh.height = 0.08
	_robot_antenna_tip.mesh = tip_mesh
	var tip_mat := StandardMaterial3D.new()
	tip_mat.albedo_color = Color(1.0, 0.9, 0.2)
	tip_mat.emission_enabled = true
	tip_mat.emission = Color(1.0, 0.9, 0.2)
	tip_mat.emission_energy_multiplier = 2.0
	_robot_antenna_tip.material_override = tip_mat
	_robot_antenna_tip.position = Vector3(0, 1.46, 0)
	mesh.add_child(_robot_antenna_tip)


func _animate_robot(delta: float) -> void:
	if not _robot_body:
		return

	_anim_time += delta
	var t := _anim_time * 3.0

	match current_state:
		State.IDLE:
			# Gentle bob
			var bob := sin(t * 2.0) * 0.02
			_robot_body.position.y = 0.55 + bob
			_robot_head.position.y = 1.05 + bob
			# Antenna sway
			_robot_antenna_pole.rotation.z = sin(t * 1.5) * 0.15
			_robot_antenna_tip.position.x = sin(t * 1.5) * 0.02
			# Reset limbs
			_robot_arm_l.rotation.x = 0.0
			_robot_arm_r.rotation.x = 0.0
			_robot_arm_l.rotation.z = 0.0
			_robot_arm_r.rotation.z = 0.0
			_robot_leg_l.rotation.x = 0.0
			_robot_leg_r.rotation.x = 0.0

		State.RUNNING:
			# Walk cycle: sin-based arm/leg swing
			var walk_speed := 12.0
			var swing := sin(t * walk_speed)
			_robot_arm_l.rotation.x = swing * 0.6
			_robot_arm_r.rotation.x = -swing * 0.6
			_robot_arm_l.rotation.z = 0.0
			_robot_arm_r.rotation.z = 0.0
			_robot_leg_l.rotation.x = -swing * 0.5
			_robot_leg_r.rotation.x = swing * 0.5
			# Slight body bob
			_robot_body.position.y = 0.55 + absf(sin(t * walk_speed * 2.0)) * 0.03
			_robot_head.position.y = 1.05 + absf(sin(t * walk_speed * 2.0)) * 0.03
			_robot_antenna_pole.rotation.z = sin(t * walk_speed) * 0.1

		State.JUMPING, State.DOUBLE_JUMPING:
			# Arms up, legs tucked
			_robot_arm_l.rotation.x = -0.8
			_robot_arm_r.rotation.x = -0.8
			_robot_leg_l.rotation.x = 0.3
			_robot_leg_r.rotation.x = 0.3
			_robot_antenna_pole.rotation.z = sin(t * 3.0) * 0.2

		State.FALLING:
			# Arms out, legs spread
			_robot_arm_l.rotation.x = -0.4
			_robot_arm_r.rotation.x = -0.4
			_robot_arm_l.rotation.z = -0.5
			_robot_arm_r.rotation.z = 0.5
			_robot_leg_l.rotation.x = -0.2
			_robot_leg_r.rotation.x = -0.2

		State.WALL_RUNNING:
			# Lean forward, fast leg cycle
			var run_speed := 16.0
			var run_swing := sin(t * run_speed)
			_robot_arm_l.rotation.x = run_swing * 0.7
			_robot_arm_r.rotation.x = -run_swing * 0.7
			_robot_leg_l.rotation.x = -run_swing * 0.6
			_robot_leg_r.rotation.x = run_swing * 0.6
			_robot_body.position.y = 0.55

		State.GROUND_POUND:
			# Tucked ball
			_robot_arm_l.rotation.x = 0.8
			_robot_arm_r.rotation.x = 0.8
			_robot_leg_l.rotation.x = 0.6
			_robot_leg_r.rotation.x = 0.6

		State.DASHING:
			# Arms back, streamlined
			_robot_arm_l.rotation.x = 1.0
			_robot_arm_r.rotation.x = 1.0
			_robot_leg_l.rotation.x = 0.2
			_robot_leg_r.rotation.x = 0.2

		State.WALL_SLIDING:
			# One arm gripping wall
			_robot_arm_l.rotation.x = -1.0
			_robot_arm_r.rotation.x = 0.3
			_robot_leg_l.rotation.x = 0.0
			_robot_leg_r.rotation.x = 0.0

		State.SLIDING:
			# Low pose, arms back
			_robot_arm_l.rotation.x = 0.8
			_robot_arm_r.rotation.x = 0.8
			_robot_leg_l.rotation.x = -0.5
			_robot_leg_r.rotation.x = -0.5

		State.GRAPPLING:
			# Right arm extended forward, left arm back, legs tucked
			_robot_arm_r.rotation.x = -1.2
			_robot_arm_r.rotation.z = 0.0
			_robot_arm_l.rotation.x = 0.6
			_robot_arm_l.rotation.z = 0.0
			_robot_leg_l.rotation.x = 0.4
			_robot_leg_r.rotation.x = 0.4
			# Slight body lean forward
			_robot_body.position.y = 0.55

		State.SPIN_ATTACK:
			# Handled by existing mesh rotation tween
			pass
