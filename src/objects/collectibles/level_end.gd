extends Area3D

## Level end goal — triggers level completion when player touches it.
## Shows level complete screen with stars and coins.

@export var next_world: int = 1
@export var next_level: int = 2

var _triggered: bool = false
var _level_complete_scene := preload("res://src/ui/level_complete.tscn")

@onready var mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if not _triggered:
		mesh.rotate_y(1.5 * delta)


func _on_body_entered(body: Node3D) -> void:
	if _triggered:
		return
	if not body is CharacterBody3D:
		return

	_triggered = true

	# Celebration animation
	var tween := create_tween()
	tween.tween_property(mesh, "scale", Vector3(2, 3, 2), 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh, "scale", Vector3.ZERO, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_interval(0.5)
	tween.tween_callback(_complete)


func _complete() -> void:
	AudioManager.play_sfx(SoundLibrary.level_complete)
	# Find level_base script on parent
	var level := _find_level_root()
	if level and level.has_method("complete_level"):
		level.complete_level()

	# Show level complete screen
	var complete_ui := _level_complete_scene.instantiate()
	get_tree().root.add_child(complete_ui)
	complete_ui.show_results(
		GameManager.current_world,
		GameManager.current_level,
		next_world,
		next_level
	)


func _find_level_root() -> Node:
	var node := get_parent()
	while node:
		if node.has_method("complete_level"):
			return node
		node = node.get_parent()
	return null
