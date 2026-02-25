extends Area3D

## Checkpoint — sets respawn point when the player touches it.
## Visually changes (scales up, color change) to show activation.

@export var checkpoint_id: int = 0

var _activated: bool = false

@onready var mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _activated:
		return
	if not body is CharacterBody3D:
		return

	_activated = true
	# Visual feedback
	var tween := create_tween()
	tween.tween_property(mesh, "scale", Vector3(1.3, 1.5, 1.3), 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh, "scale", Vector3(1.0, 1.2, 1.0), 0.1)
