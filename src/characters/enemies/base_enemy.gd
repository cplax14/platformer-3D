extends CharacterBody3D
class_name BaseEnemy

## Base enemy — shared logic for all enemy types.
## Handles health, damage from player attacks, death, and gravity.

signal died

@export var max_hp: int = 1
@export var gravity: float = 20.0
@export var knockback_on_death: float = 5.0

var hp: int
var _is_dead: bool = false

@onready var mesh: Node3D = $Mesh
@onready var collision_shape: CollisionShape3D = $CollisionShape
@onready var hurtbox: Area3D = $Hurtbox  # Detects player attacks


func _ready() -> void:
	hp = max_hp
	collision_layer = 4  # Enemies layer
	collision_mask = 2   # Collide with environment

	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	_enemy_ready()


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	_enemy_process(delta)
	move_and_slide()


## Override in subclasses for enemy-specific setup.
func _enemy_ready() -> void:
	pass


## Override in subclasses for enemy-specific behavior.
func _enemy_process(_delta: float) -> void:
	pass


## Called when player's attack area overlaps the enemy's hurtbox.
func _on_hurtbox_area_entered(area: Area3D) -> void:
	if _is_dead:
		return

	# Check if the area belongs to the player (SpinAttackArea or GroundPoundArea)
	var parent := area.get_parent()
	if parent and parent is CharacterBody3D:
		take_hit(1, parent.global_position)


func take_hit(damage: int, from_position: Vector3) -> void:
	if _is_dead:
		return

	hp -= damage
	if hp <= 0:
		_die(from_position)
	else:
		_on_hurt(from_position)


## Override for custom hurt reaction (flash, knockback, etc.)
func _on_hurt(_from_position: Vector3) -> void:
	# Default: brief red flash
	_flash_red()


func _die(from_position: Vector3) -> void:
	_is_dead = true
	died.emit()
	Particles.spawn_enemy_death(global_position + Vector3(0, 0.5, 0))
	ScreenShake.shake_light()

	# Disable collision immediately
	collision_shape.set_deferred("disabled", true)
	hurtbox.set_deferred("monitoring", false)

	# Death animation: squash, pop upward, shrink
	var dir := (global_position - from_position).normalized()
	dir.y = 0.0

	var tween := create_tween()
	tween.set_parallel(true)
	# Squash
	tween.tween_property(mesh, "scale", Vector3(1.5, 0.2, 1.5), 0.1)
	# Pop up and away
	tween.tween_property(self, "position",
		position + Vector3(dir.x * knockback_on_death, 3.0, dir.z * knockback_on_death),
		0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Spin
	tween.tween_property(mesh, "rotation:x", TAU * 2, 0.4)
	# Then shrink
	tween.chain().tween_property(mesh, "scale", Vector3.ZERO, 0.15)
	tween.chain().tween_callback(queue_free)


func _flash_red() -> void:
	if mesh is MeshInstance3D:
		var mat := mesh as MeshInstance3D
		# Simple approach: tween modulate if using a shader, or scale pulse
		var tween := create_tween()
		tween.tween_property(mesh, "scale", Vector3(1.3, 0.7, 1.3), 0.05)
		tween.tween_property(mesh, "scale", Vector3.ONE, 0.1)


## Damage the player on contact. Call from subclass body_entered signals.
func _damage_player(body: Node3D) -> void:
	if _is_dead:
		return
	if not body.has_method("take_damage"):
		return

	GameManager.take_damage(1)
	body.take_damage(global_position)
