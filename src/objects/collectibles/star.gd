extends Area3D

## Star collectible — one of 3 per level. Spins and glows.
## star_index should be 0, 1, or 2 (set per instance in the editor).

@export var star_index: int = 0
@export var bob_height: float = 0.4
@export var bob_speed: float = 1.0
@export var rotation_speed: float = 1.5

var _base_y: float = 0.0
var _time: float = 0.0
var _collected: bool = false


func _ready() -> void:
	_base_y = position.y
	_time = randf() * TAU
	body_entered.connect(_on_body_entered)
	var mesh_node := get_node_or_null("MeshInstance3D")
	if mesh_node and MaterialLibrary:
		mesh_node.material_override = MaterialLibrary.get_material("star")

	# Hide if already collected in this session
	var level_id := "%d_%d" % [GameManager.current_world, GameManager.current_level]
	var stars: Array = GameManager.collected_stars.get(level_id, [false, false, false])
	if star_index < stars.size() and stars[star_index]:
		_collected = true
		visible = false
		set_deferred("monitoring", false)


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
	GameManager.collect_star(star_index)
	Particles.spawn_star_collect(global_position)
	ScreenShake.shake_light()
	AudioManager.play_sfx(SoundLibrary.star)

	# Dramatic collect: scale up then vanish
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 2.0, 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
