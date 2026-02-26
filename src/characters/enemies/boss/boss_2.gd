extends CharacterBody3D

## Boss 2 — "Crystal Golem"
## 3 attack patterns:
##   1. CRYSTAL_RAIN — spawn falling crystal projectiles at random arena positions
##   2. SLAM — jump + slam with shockwave (like boss_1)
##   3. SUMMON — spawn 2 crystal bats (max 4 alive)
## After each attack, pauses (vulnerable window). 8 HP.

signal boss_died
signal health_changed(current_hp: int, max_hp: int)

enum Phase { INTRO, IDLE, CRYSTAL_RAIN, SLAM, SUMMON, VULNERABLE, DEAD }

@export var max_hp: int = 8
@export var slam_height: float = 10.0
@export var vulnerable_time: float = 2.5
@export var idle_time: float = 1.5
@export var max_summoned_bats: int = 4

var hp: int
var _phase: Phase = Phase.INTRO
var _phase_timer: float = 0.0
var _attack_index: int = 0
var _player: CharacterBody3D = null
var _arena_center: Vector3 = Vector3.ZERO
var _is_invincible: bool = true
var _summoned_bats: Array[Node] = []

@onready var mesh: Node3D = $Mesh
@onready var collision_shape: CollisionShape3D = $CollisionShape
@onready var hurtbox: Area3D = $Hurtbox
@onready var damage_area: Area3D = $DamageArea
@onready var shockwave_area: Area3D = $ShockwaveArea

var _attack_order: Array[Phase] = [Phase.CRYSTAL_RAIN, Phase.SLAM, Phase.SUMMON]
var _bat_scene: PackedScene = preload("res://src/characters/enemies/crystal_bat/crystal_bat.tscn")


func _ready() -> void:
	hp = max_hp
	_arena_center = global_position
	hurtbox.area_entered.connect(_on_hurtbox_hit)
	damage_area.body_entered.connect(_on_body_contact)
	shockwave_area.monitoring = false

	_phase = Phase.INTRO
	_phase_timer = 2.0

	if mesh and MaterialLibrary:
		mesh.material_override = MaterialLibrary.get_material("boss_crystal")

	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]

	health_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
	if _phase == Phase.DEAD:
		return

	_phase_timer -= delta

	match _phase:
		Phase.INTRO:
			_process_intro(delta)
		Phase.IDLE:
			_process_idle(delta)
		Phase.CRYSTAL_RAIN:
			_process_crystal_rain(delta)
		Phase.SLAM:
			_process_slam(delta)
		Phase.SUMMON:
			_process_summon(delta)
		Phase.VULNERABLE:
			_process_vulnerable(delta)

	move_and_slide()


# === INTRO ===
func _process_intro(_delta: float) -> void:
	mesh.scale = Vector3.ONE * (1.0 + sin(_phase_timer * 4.0) * 0.1)
	if _phase_timer <= 0.0:
		_start_idle()


# === IDLE ===
func _start_idle() -> void:
	_phase = Phase.IDLE
	_phase_timer = idle_time
	_is_invincible = true
	velocity = Vector3.ZERO


func _process_idle(delta: float) -> void:
	if _player:
		var dir := (_player.global_position - global_position)
		dir.y = 0.0
		if dir.length() > 0.1:
			rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 3.0 * delta)

	if _phase_timer <= 0.0:
		_start_next_attack()


func _start_next_attack() -> void:
	var attack := _attack_order[_attack_index % _attack_order.size()]
	_attack_index += 1

	match attack:
		Phase.CRYSTAL_RAIN:
			_start_crystal_rain()
		Phase.SLAM:
			_start_slam()
		Phase.SUMMON:
			_start_summon()


# === CRYSTAL RAIN ===
func _start_crystal_rain() -> void:
	_phase = Phase.CRYSTAL_RAIN
	_phase_timer = 2.0
	_is_invincible = true
	_spawn_crystal_rain()


func _process_crystal_rain(_delta: float) -> void:
	if _phase_timer <= 0.0:
		_start_vulnerable()


func _spawn_crystal_rain() -> void:
	# Spawn 6 falling crystal projectiles at random arena positions
	for i in range(6):
		var offset := Vector3(
			randf_range(-8.0, 8.0),
			12.0,
			randf_range(-8.0, 8.0)
		)
		var proj := _create_crystal_projectile()
		get_parent().add_child(proj)
		proj.global_position = _arena_center + offset
		proj.set_meta("direction", Vector3.DOWN)
		proj.set_meta("speed", 8.0)

	AudioManager.play_sfx(SoundLibrary.crystal_shatter)


# === SLAM ===
func _start_slam() -> void:
	_phase = Phase.SLAM
	_phase_timer = 1.5
	_is_invincible = true

	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y + slam_height, 0.6).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.3)
	tween.tween_property(self, "position:y", _arena_center.y, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(_slam_impact)


func _process_slam(_delta: float) -> void:
	if _phase_timer <= 0.0:
		_start_vulnerable()


func _slam_impact() -> void:
	shockwave_area.monitoring = true
	Particles.spawn_ground_pound_impact(global_position)
	ScreenShake.shake_medium()

	await get_tree().create_timer(0.3).timeout
	shockwave_area.monitoring = false


# === SUMMON ===
func _start_summon() -> void:
	_phase = Phase.SUMMON
	_phase_timer = 1.5
	_is_invincible = true

	# Windup telegraph
	var tween := create_tween()
	tween.tween_property(mesh, "scale", Vector3(1.3, 0.7, 1.3), 0.3)
	tween.tween_property(mesh, "scale", Vector3.ONE, 0.2)
	tween.tween_callback(_spawn_bats)


func _process_summon(_delta: float) -> void:
	if _phase_timer <= 0.0:
		_start_vulnerable()


func _spawn_bats() -> void:
	# Clean up dead bat references
	var alive_bats: Array[Node] = []
	for bat in _summoned_bats:
		if is_instance_valid(bat):
			alive_bats.append(bat)
	_summoned_bats = alive_bats

	var bats_to_spawn := mini(2, max_summoned_bats - _summoned_bats.size())
	for i in range(bats_to_spawn):
		var bat := _bat_scene.instantiate()
		var offset := Vector3(
			randf_range(-4.0, 4.0),
			0.0,
			randf_range(-4.0, 4.0)
		)
		get_parent().add_child(bat)
		bat.global_position = global_position + offset + Vector3(0, 3.0, 0)
		_summoned_bats.append(bat)

	AudioManager.play_sfx(SoundLibrary.bat_screech)


# === VULNERABLE ===
func _start_vulnerable() -> void:
	_phase = Phase.VULNERABLE
	_phase_timer = vulnerable_time
	_is_invincible = false
	velocity = Vector3.ZERO

	var tween := create_tween()
	tween.set_loops(int(vulnerable_time / 0.3))
	tween.tween_property(mesh, "rotation:z", 0.15, 0.15)
	tween.tween_property(mesh, "rotation:z", -0.15, 0.15)


func _process_vulnerable(_delta: float) -> void:
	if _phase_timer <= 0.0:
		mesh.rotation.z = 0.0
		_start_idle()


# === DAMAGE ===
func _on_hurtbox_hit(area: Area3D) -> void:
	if _is_invincible or _phase == Phase.DEAD:
		return

	var parent := area.get_parent()
	if parent and parent is CharacterBody3D:
		hp -= 1
		health_changed.emit(hp, max_hp)

		if hp <= 0:
			_die()
		else:
			_flash_hurt()


func _on_body_contact(body: Node3D) -> void:
	if _phase == Phase.DEAD:
		return
	if body.has_method("take_damage"):
		GameManager.take_damage(1)
		body.take_damage(global_position)


func _flash_hurt() -> void:
	# Hitstop — brief freeze for impact feel
	get_tree().paused = true
	await get_tree().create_timer(0.06).timeout
	get_tree().paused = false

	# Screen shake
	ScreenShake.shake_medium()

	# SFX
	AudioManager.play_sfx(SoundLibrary.enemy_hit)

	# Damage particles burst from the boss
	Particles.spawn_crystal_sparkle(global_position + Vector3(0, 1.0, 0))

	# Red flash + dramatic squash
	Juice.flash(mesh, Color(1.0, 0.0, 0.0), 0.25)
	var tween := create_tween()
	tween.tween_property(mesh, "scale", Vector3(1.6, 0.4, 1.6), 0.06).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh, "scale", Vector3(0.8, 1.4, 0.8), 0.08).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh, "scale", Vector3.ONE, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

	# Knockback jitter
	Juice.shake_node(mesh, 0.15, 0.2)


func _die() -> void:
	_phase = Phase.DEAD
	_is_invincible = true
	velocity = Vector3.ZERO
	collision_shape.set_deferred("disabled", true)
	damage_area.set_deferred("monitoring", false)

	# Kill all summoned bats
	for bat in _summoned_bats:
		if is_instance_valid(bat):
			bat.queue_free()
	_summoned_bats.clear()

	Particles.spawn_crystal_sparkle(global_position + Vector3(0, 1.0, 0))
	AudioManager.play_sfx(SoundLibrary.crystal_shatter)

	var tween := create_tween()
	tween.tween_property(mesh, "scale", Vector3(2.0, 0.1, 2.0), 0.3)
	tween.tween_property(self, "position:y", position.y + 5.0, 0.4).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(mesh, "scale", Vector3.ZERO, 0.3)
	tween.chain().tween_callback(func():
		boss_died.emit()
		queue_free()
	)


func _create_crystal_projectile() -> Area3D:
	var proj := Area3D.new()
	proj.collision_layer = 8
	proj.collision_mask = 1

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.5, 0.3)
	mesh_inst.mesh = box
	if MaterialLibrary:
		mesh_inst.material_override = MaterialLibrary.get_material("crystal")
	proj.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.4, 0.6, 0.4)
	col.shape = shape
	proj.add_child(col)

	proj.set_script(_get_projectile_script())
	return proj


func _get_projectile_script() -> GDScript:
	if not Engine.has_meta("crystal_projectile_script"):
		var script := GDScript.new()
		script.source_code = """extends Area3D

var direction: Vector3 = Vector3.DOWN
var speed: float = 8.0
var lifetime: float = 4.0

func _ready() -> void:
	if has_meta("direction"):
		direction = get_meta("direction")
	if has_meta("speed"):
		speed = get_meta("speed")
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("take_damage"):
		GameManager.take_damage(1)
		body.take_damage(global_position)
	queue_free()
"""
		script.reload()
		Engine.set_meta("crystal_projectile_script", script)
	return Engine.get_meta("crystal_projectile_script")
