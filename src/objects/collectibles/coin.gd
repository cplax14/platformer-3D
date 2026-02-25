extends Area3D

## Coin collectible — rotates, bobs, bursts particles on collect.

@export var coin_value: int = 1
@export var bob_height: float = 0.3
@export var bob_speed: float = 2.0
@export var rotation_speed: float = 3.0

var _base_y: float = 0.0
var _time: float = 0.0
var _collected: bool = false


func _ready() -> void:
	_base_y = position.y
	_time = randf() * TAU  # Random start phase so coins don't sync
	body_entered.connect(_on_body_entered)
	var mesh_node := get_node_or_null("MeshInstance3D")
	if mesh_node and MaterialLibrary:
		mesh_node.material_override = MaterialLibrary.get_material("coin")


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

	_collected = true
	GameManager.add_coins(coin_value)
	_play_collect_effect()


func _play_collect_effect() -> void:
	Particles.spawn_coin_collect(global_position)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.2).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
