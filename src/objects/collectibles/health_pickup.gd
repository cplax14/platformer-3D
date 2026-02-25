extends Area3D

## Health pickup — restores 1 heart. Bobs and glows.

@export var heal_amount: int = 1
@export var bob_height: float = 0.2
@export var bob_speed: float = 1.5
@export var rotation_speed: float = 2.0

var _base_y: float = 0.0
var _time: float = 0.0
var _collected: bool = false


func _ready() -> void:
	_base_y = position.y
	_time = randf() * TAU
	body_entered.connect(_on_body_entered)
	var mesh_node := get_node_or_null("MeshInstance3D")
	if mesh_node and MaterialLibrary:
		mesh_node.material_override = MaterialLibrary.get_material("health")


func _process(delta: float) -> void:
	if _collected:
		return

	_time += delta
	position.y = _base_y + sin(_time * bob_speed) * bob_height
	rotate_y(rotation_speed * delta)


func _on_body_entered(body: Node3D) -> void:
	if _collected:
		return
	if not body is CharacterBody3D:
		return

	# Only collect if player is missing health
	if GameManager.health >= GameManager.max_health:
		return

	_collected = true
	GameManager.heal(heal_amount)
	Particles.spawn_health_collect(global_position)

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.2).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
