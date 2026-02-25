extends CharacterBody3D

## Boss 1 — "King Slime"
## 3 attack patterns, telegraphed for kids to read:
##   1. SLAM: Jumps up, slams down (shockwave)
##   2. BARRAGE: Spits 5 slow projectiles in a fan
##   3. CHARGE: Winds up then charges across arena
## After each attack, pauses (vulnerable window).

signal boss_died
signal health_changed(current_hp: int, max_hp: int)

enum Phase { INTRO, IDLE, SLAM, BARRAGE, CHARGE, VULNERABLE, DEAD }

@export var max_hp: int = 6
@export var slam_height: float = 10.0
@export var charge_speed: float = 10.0
@export var projectile_speed: float = 5.0
@export var vulnerable_time: float = 2.5
@export var idle_time: float = 1.5

var hp: int
var _phase: Phase = Phase.INTRO
var _phase_timer: float = 0.0
var _attack_index: int = 0
var _player: CharacterBody3D = null
var _arena_center: Vector3 = Vector3.ZERO
var _charge_dir: Vector3 = Vector3.ZERO
var _is_invincible: bool = true

@onready var mesh: Node3D = $Mesh
@onready var collision_shape: CollisionShape3D = $CollisionShape
@onready var hurtbox: Area3D = $Hurtbox
@onready var damage_area: Area3D = $DamageArea
@onready var shockwave_area: Area3D = $ShockwaveArea

var _attack_order: Array[Phase] = [Phase.SLAM, Phase.BARRAGE, Phase.CHARGE]


func _ready() -> void:
	hp = max_hp
	_arena_center = global_position
	hurtbox.area_entered.connect(_on_hurtbox_hit)
	damage_area.body_entered.connect(_on_body_contact)
	shockwave_area.monitoring = false

	# Brief intro before fighting
	_phase = Phase.INTRO
	_phase_timer = 2.0

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
		Phase.SLAM:
			_process_slam(delta)
		Phase.BARRAGE:
			_process_barrage(delta)
		Phase.CHARGE:
			_process_charge(delta)
		Phase.VULNERABLE:
			_process_vulnerable(delta)

	move_and_slide()


# === INTRO ===
func _process_intro(_delta: float) -> void:
	# Bounce menacingly
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
	# Face the player
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
		Phase.SLAM:
			_start_slam()
		Phase.BARRAGE:
			_start_barrage()
		Phase.CHARGE:
			_start_charge()


# === SLAM ===
func _start_slam() -> void:
	_phase = Phase.SLAM
	_phase_timer = 1.5  # Total slam duration
	_is_invincible = true

	# Jump up
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y + slam_height, 0.6).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.3)
	tween.tween_property(self, "position:y", _arena_center.y, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(_slam_impact)


func _process_slam(_delta: float) -> void:
	if _phase_timer <= 0.0:
		_start_vulnerable()


func _slam_impact() -> void:
	# Activate shockwave
	shockwave_area.monitoring = true
	# Camera shake would go here

	# Brief shockwave then disable
	await get_tree().create_timer(0.3).timeout
	shockwave_area.monitoring = false


# === BARRAGE ===
func _start_barrage() -> void:
	_phase = Phase.BARRAGE
	_phase_timer = 1.5
	_is_invincible = true
	_fire_fan()


func _process_barrage(_delta: float) -> void:
	if _phase_timer <= 0.0:
		_start_vulnerable()


func _fire_fan() -> void:
	if not _player:
		return

	var base_dir := (_player.global_position - global_position)
	base_dir.y = 0.0
	base_dir = base_dir.normalized()

	# 5 projectiles in a fan pattern
	for i in range(5):
		var angle_offset := deg_to_rad(-40.0 + i * 20.0)
		var dir := base_dir.rotated(Vector3.UP, angle_offset)

		var proj := _create_projectile()
		get_parent().add_child(proj)
		proj.global_position = global_position + Vector3(0, 1.5, 0) + dir * 1.5
		proj.set_meta("direction", dir)
		proj.set_meta("speed", projectile_speed)


# === CHARGE ===
func _start_charge() -> void:
	_phase = Phase.CHARGE
	_phase_timer = 2.0
	_is_invincible = true

	if _player:
		_charge_dir = (_player.global_position - global_position)
		_charge_dir.y = 0.0
		_charge_dir = _charge_dir.normalized()

	# Windup telegraph
	var tween := create_tween()
	tween.tween_property(mesh, "scale", Vector3(1.4, 0.6, 1.4), 0.4)
	tween.tween_property(mesh, "scale", Vector3(0.8, 1.3, 0.8), 0.2)
	tween.tween_callback(func(): velocity = _charge_dir * charge_speed)


func _process_charge(_delta: float) -> void:
	# Stop charging when timer runs out or hits wall
	if _phase_timer <= 0.0:
		velocity = Vector3.ZERO
		mesh.scale = Vector3.ONE
		_start_vulnerable()
	elif is_on_wall():
		velocity = Vector3.ZERO
		mesh.scale = Vector3.ONE
		# Stunned from wall hit — extra vulnerable time
		_start_vulnerable()


# === VULNERABLE ===
func _start_vulnerable() -> void:
	_phase = Phase.VULNERABLE
	_phase_timer = vulnerable_time
	_is_invincible = false
	velocity = Vector3.ZERO

	# Dizzy animation
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
	var tween := create_tween()
	tween.tween_property(mesh, "scale", Vector3(1.3, 0.7, 1.3), 0.05)
	tween.tween_property(mesh, "scale", Vector3.ONE, 0.1)


func _die() -> void:
	_phase = Phase.DEAD
	_is_invincible = true
	velocity = Vector3.ZERO
	collision_shape.set_deferred("disabled", true)
	damage_area.set_deferred("monitoring", false)

	var tween := create_tween()
	tween.tween_property(mesh, "scale", Vector3(2.0, 0.1, 2.0), 0.3)
	tween.tween_property(self, "position:y", position.y + 5.0, 0.4).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(mesh, "scale", Vector3.ZERO, 0.3)
	tween.chain().tween_callback(func():
		boss_died.emit()
		queue_free()
	)


func _create_projectile() -> Area3D:
	var proj := Area3D.new()
	proj.collision_layer = 8
	proj.collision_mask = 1

	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	mesh_inst.mesh = sphere
	proj.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.25
	col.shape = shape
	proj.add_child(col)

	proj.set_script(_get_projectile_script())
	return proj


func _get_projectile_script() -> GDScript:
	if not Engine.has_meta("boss_projectile_script"):
		var script := GDScript.new()
		script.source_code = """extends Area3D

var direction: Vector3 = Vector3.FORWARD
var speed: float = 5.0
var lifetime: float = 6.0

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
		Engine.set_meta("boss_projectile_script", script)
	return Engine.get_meta("boss_projectile_script")
