extends BaseEnemy

## Turret — stationary, shoots slow projectiles at intervals. 2 HP.

@export var fire_interval: float = 3.0
@export var projectile_speed: float = 6.0
@export var detection_range: float = 15.0

var _fire_timer: float = 0.0
var _player: CharacterBody3D = null


func _enemy_ready() -> void:
	max_hp = 2
	hp = 2
	_fire_timer = fire_interval


func _enemy_process(delta: float) -> void:
	_find_player()

	if not _player:
		return

	var distance := global_position.distance_to(_player.global_position)
	if distance > detection_range:
		return

	# Face the player (Y rotation only)
	var look_dir := (_player.global_position - global_position)
	look_dir.y = 0.0
	if look_dir.length() > 0.1:
		var target_angle := atan2(look_dir.x, look_dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 3.0 * delta)

	# Fire on interval
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_interval
		_fire_projectile()


func _find_player() -> void:
	if _player:
		return
	# Find player in the scene
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0] as CharacterBody3D
	else:
		# Fallback: search by class
		for node in get_tree().get_nodes_in_group(""):
			pass  # Player will be found via detection range check


func _fire_projectile() -> void:
	if not _player:
		return

	var projectile := _create_projectile()
	get_parent().add_child(projectile)
	projectile.global_position = global_position + Vector3(0, 0.5, 0)

	# Aim at player with slight lead
	var dir := (_player.global_position + Vector3(0, 0.5, 0) - projectile.global_position).normalized()
	projectile.set_meta("direction", dir)
	projectile.set_meta("speed", projectile_speed)


func _create_projectile() -> Area3D:
	var proj := Area3D.new()
	proj.collision_layer = 8  # Hazards layer
	proj.collision_mask = 3   # Player + Environment

	# Mesh
	var mesh_inst := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.15
	sphere_mesh.height = 0.3
	mesh_inst.mesh = sphere_mesh
	proj.add_child(mesh_inst)

	# Collision
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.2
	col.shape = shape
	proj.add_child(col)

	# Script-like behavior via callable
	proj.set_script(_get_projectile_script())

	return proj


func _get_projectile_script() -> GDScript:
	if not Engine.has_meta("turret_projectile_script"):
		var script := GDScript.new()
		script.source_code = """extends Area3D

var direction: Vector3 = Vector3.FORWARD
var speed: float = 6.0
var lifetime: float = 5.0

func _ready() -> void:
	if has_meta("direction"):
		direction = get_meta("direction")
	if has_meta("speed"):
		speed = get_meta("speed")
	body_entered.connect(_on_body_entered)
	# Auto-destroy after lifetime
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
		Engine.set_meta("turret_projectile_script", script)
	return Engine.get_meta("turret_projectile_script")
