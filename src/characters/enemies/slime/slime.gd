extends BaseEnemy

## Slime — patrols back and forth. 1 HP. Damages player on contact.

@export var patrol_speed: float = 2.0
@export var patrol_distance: float = 4.0
@export var bob_amount: float = 0.1
@export var bob_speed: float = 4.0

var _patrol_direction: float = 1.0
var _start_position: Vector3
var _time: float = 0.0

@onready var player_damage_area: Area3D = $PlayerDamageArea


func _enemy_ready() -> void:
	_start_position = global_position
	player_damage_area.body_entered.connect(_on_player_contact)
	if mesh and MaterialLibrary:
		mesh.material_override = MaterialLibrary.get_material("slime")


func _enemy_process(delta: float) -> void:
	_time += delta

	# Patrol back and forth
	velocity.x = patrol_speed * _patrol_direction

	# Check if we've gone far enough from start
	var distance_from_start := global_position.x - _start_position.x
	if absf(distance_from_start) >= patrol_distance:
		_patrol_direction *= -1.0

	# Face movement direction
	if _patrol_direction > 0:
		mesh.rotation.y = 0.0
	else:
		mesh.rotation.y = PI

	# Squishy bob animation
	var bob := sin(_time * bob_speed) * bob_amount
	mesh.scale = Vector3(1.0 + bob * 0.3, 1.0 - bob * 0.3, 1.0 + bob * 0.3)


func _on_player_contact(body: Node3D) -> void:
	_damage_player(body)
