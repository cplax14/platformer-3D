extends StaticBody3D

## Bouncy platform — launches the player upward on contact.

@export var bounce_force: float = 18.0
@export var squash_amount: float = 0.3  # Visual squash when bounced

@onready var detection_area: Area3D = $DetectionArea
@onready var mesh: CSGBox3D = $CSGBox3D

var _original_scale: Vector3


func _ready() -> void:
	_original_scale = mesh.scale
	detection_area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return

	# Only bounce if player is above the platform (not approaching from the side)
	if body.global_position.y < global_position.y:
		return

	body.velocity.y = bounce_force
	_play_bounce_animation()


func _play_bounce_animation() -> void:
	# Squash then spring back
	var squashed := Vector3(_original_scale.x * 1.2, _original_scale.y * squash_amount, _original_scale.z * 1.2)
	var stretched := Vector3(_original_scale.x * 0.9, _original_scale.y * 1.3, _original_scale.z * 0.9)

	var tween := create_tween()
	tween.tween_property(mesh, "scale", squashed, 0.05)
	tween.tween_property(mesh, "scale", stretched, 0.1)
	tween.tween_property(mesh, "scale", _original_scale, 0.15).set_ease(Tween.EASE_OUT)
